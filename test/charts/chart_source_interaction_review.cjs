const assert = require('node:assert/strict');
const puppeteer = require(process.env.BEUI_REVIEW_PUPPETEER || 'puppeteer-core');

async function review() {
  const browser = await puppeteer.launch({
    executablePath: process.env.BEUI_REVIEW_CHROME ||
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
  });
  try {
    for (const touch of [false, true]) {
      const page = await browser.newPage();
      await page.setViewport({ width: 1280, height: 1000, hasTouch: touch });
      await page.emulateMediaFeatures([
        { name: 'prefers-reduced-motion', value: 'reduce' },
      ]);
      const origin = process.env.BEUI_REVIEW_SOURCE_ORIGIN || 'https://beui.dev';
      await page.goto(`${origin}/charts/price-target-fan`, { waitUntil: 'domcontentloaded' });
      const high = 'svg [role="button"][aria-label^="High target"]';
      await page.waitForSelector(high);
      await page.evaluate(() => document.fonts.ready);
      await page.waitForFunction(() =>
        document.querySelector('svg clipPath rect')?.getBBox().width > 0);
      async function selected(event, expected) {
        await page.waitForFunction((selector, pressed) =>
          document.querySelector(selector)?.getAttribute('aria-pressed') === pressed,
        {}, high, String(expected));
        if (expected) {
          await page.waitForSelector('[role="tooltip"]');
        } else {
          await page.waitForSelector('[role="tooltip"]', { hidden: true });
        }
        const state = await page.$eval(high, (element, event) => ({
          event,
          pressed: element.getAttribute('aria-pressed'),
          tooltips: [...document.querySelectorAll('[role="tooltip"]')]
            .map(tooltip => tooltip.textContent),
        }), event);
        assert.equal(state.pressed, String(expected));
        assert.equal(state.tooltips.length, expected ? 1 : 0);
        console.log(JSON.stringify({ url: page.url(), touch, ...state }));
      }
      if (touch) {
        const point = await page.$eval(high, element => {
          const rect = element.querySelector('circle').getBoundingClientRect();
          return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
        });
        await page.touchscreen.tap(point.x, point.y);
        await selected('first touch', true);
        await page.touchscreen.tap(point.x, point.y);
        await selected('second touch', false);
      } else {
        await page.$eval(high, element => element.focus());
        await selected('focus', true);
        for (const key of ['Enter', 'Space']) {
          await page.keyboard.press(key);
          await selected(`${key} off`, false);
          await page.keyboard.press(key);
          await selected(`${key} on`, true);
        }
      }
      await page.close();
    }
  } finally {
    await browser.close();
  }
}

review().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
