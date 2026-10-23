import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const observations = [];
const browser = await chromium.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
try {
  for (const preference of ['reduce', 'no-preference']) {
  for (const source of [true, false]) {
    const page = await browser.newPage({viewport: {width: 1280, height: 1000}, reducedMotion: preference});
    await page.goto(`http://127.0.0.1:8109/${source ? 'source/' : ''}?theme=${preference === 'reduce' ? 'light' : 'dark'}`, {waitUntil: 'domcontentloaded'});
    await page.waitForTimeout(2000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    for (const [key, expected] of [['Tab', true], ['r', false], ['i', false], ['ArrowRight', true], ['Escape', false]]) {
      await page.keyboard.press(key);
      await page.waitForTimeout(350);
      const state = await page.evaluate(source => {
        globalThis.__ownershipFocusedElement ??= document.activeElement;
        const elements = source
          ? [...document.querySelectorAll('[role="tooltip"]')]
          : [...document.querySelectorAll('flt-semantics')];
        const readout = elements.filter(element => {
          const rect = element.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0 && element.textContent.includes('Tuesday detail');
        });
        const focused = document.activeElement;
        return {
          visibleTuesday: readout.length > 0,
          focusRetained: document.activeElement === globalThis.__ownershipFocusedElement,
          focused: {tag: focused?.tagName, role: focused?.getAttribute('role'), label: focused?.getAttribute('aria-label'), id: focused?.id},
          text: [...document.querySelectorAll(source ? 'main' : 'flt-semantics')].map(element => element.textContent).filter(Boolean),
        };
      }, source);
      observations.push({source, preference, key, expected, ...state});
      assert.equal(state.visibleTuesday, expected, JSON.stringify(observations));
      assert.equal(state.focusRetained, true);
    }
    await page.close();
  }
  }
} finally {
  await writeFile(process.argv[2], JSON.stringify(observations, null, 2), {flag: 'wx'});
  await browser.close();
}
