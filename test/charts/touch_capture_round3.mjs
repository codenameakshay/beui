import {chromium as nativeChromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

// Chart-only transport for the unchanged shared screenshot recorder.
// Its click actions become trusted touch taps, not mouse clicks or DOM events.
export const chromium = {
  async launch(options) {
    const browser = await nativeChromium.launch(options);
    const pages = [];
    const createContext = browser.newContext.bind(browser);
    browser.newContext = async options => {
      const context = await createContext({...options, hasTouch: true});
      await context.addInitScript(() => {
        globalThis.__chartTouchEvents = [];
        for (const type of ['pointerdown', 'pointerup', 'click']) {
          document.addEventListener(type, event => globalThis.__chartTouchEvents.push({
            type, pointerType: event.pointerType, isTrusted: event.isTrusted,
            x: event.clientX, y: event.clientY, timeStamp: event.timeStamp,
          }), true);
        }
      });
      const createPage = context.newPage.bind(context);
      context.newPage = async () => {
        const page = await createPage();
        pages.push(page);
        let started = false;
        page.mouse.click = async (x, y, options) => {
          assert.equal(options.button, 'left');
          if (!started) {
            await page.evaluate(() => globalThis.__chartTouchEvents = []);
            started = true;
          }
          await page.touchscreen.tap(x, y);
        };
        return page;
      };
      return context;
    };
    const close = browser.close.bind(browser);
    browser.close = async () => {
      try {
        const observations = await Promise.all(pages.map(page => page.evaluate(() => ({
          url: location.href, maxTouchPoints: navigator.maxTouchPoints,
          hoverCapable: matchMedia('(hover: hover)').matches,
          events: globalThis.__chartTouchEvents,
        }))));
        assert(process.env.PARITY_TOUCH_OBSERVATION);
        await writeFile(process.env.PARITY_TOUCH_OBSERVATION, JSON.stringify(observations, null, 2), {flag: 'wx'});
        for (const observation of observations) {
          const touches = observation.events.filter(event => event.type === 'pointerdown');
          assert(touches.length >= 2);
          assert(touches.every(event => event.pointerType === 'touch' && event.isTrusted));
        }
      } finally {
        await close();
      }
    };
    return browser;
  },
};
