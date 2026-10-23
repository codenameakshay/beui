import {chromium as nativeChromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';

export const chromium = {
  async launch(options) {
    const browser = await nativeChromium.launch(options);
    const newContext = browser.newContext.bind(browser);
    const observations = [];
    browser.newContext = async options => {
      const context = await newContext({...options, hasTouch: process.env.ROUND4_TOUCH === '1'});
      const newPage = context.newPage.bind(context);
      context.newPage = async () => {
        const page = await newPage();
        await page.addInitScript(() => {
          globalThis.__round4Inputs = [];
          for (const type of ['pointerdown','pointerup','click','keydown']) document.addEventListener(type,e => {
            globalThis.__round4Inputs.push({type, key:e.key, pointerType:e.pointerType,isTrusted:e.isTrusted,x:e.clientX,y:e.clientY});
          },true);
        });
        const goto = page.goto.bind(page);
        page.goto = async (...args) => {
          const result = await goto(...args);
          await page.waitForTimeout(2500);
          await page.locator('flt-semantics-placeholder').evaluateAll(nodes => nodes.forEach(node => node.click()));
          return result;
        };
        const press = page.keyboard.press.bind(page.keyboard);
        const observe = async action => {
          await page.waitForTimeout(50);
          observations.push(await page.evaluate(action => ({action,url:location.href,probe:globalThis.__beuiCapture,
            focus:{tag:document.activeElement?.tagName,label:document.activeElement?.getAttribute('aria-label')},
            values:[...document.querySelectorAll('[aria-valuetext]')].map(e=>e.getAttribute('aria-valuetext')),
            tooltips:[...document.querySelectorAll('[role="tooltip"]')].map(e=>e.textContent),
            inputs:globalThis.__round4Inputs,
          }),action));
        };
        page.keyboard.press = async key => {await press(key);await observe(key);};
        if (process.env.ROUND4_TOUCH === '1') page.mouse.click = async (x,y) => {await page.touchscreen.tap(x,y);await observe('touch');};
        return page;
      };
      return context;
    };
    const close = browser.close.bind(browser);
    browser.close = async () => {
      try {if (process.env.ROUND4_OBSERVATIONS) await writeFile(process.env.ROUND4_OBSERVATIONS,JSON.stringify(observations,null,2),{flag:'wx'});}
      finally {await close();}
    };
    return browser;
  },
};
