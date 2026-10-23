import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = 'docs/proof/v3-parity/charts/round3';
const output = resolve(process.argv[2]);
await mkdir(output);
const wrapperSha256 = createHash('sha256').update(await readFile('test/charts/touch_capture_round3.mjs')).digest('hex');
const browser = await chromium.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
try {
  for (const reference of [false, true]) {
    for (const [theme, preference] of [['dark', 'no-preference'], ['light', 'reduce']]) {
      const basePath = reference
        ? `${root}/configs-final-v4/reference-price-target-fan-${theme}-${preference}.json`
        : `${root}/${process.argv[3] ?? 'configs-final-v9'}/after-price-target-fan-${theme}-${preference}.json`;
      const config = JSON.parse(await readFile(basePath));
      if (reference) {
        const page = await browser.newPage({viewport: config.viewport, hasTouch: true, colorScheme: theme, reducedMotion: preference});
        await page.goto(config.url, {waitUntil: 'domcontentloaded'});
        await page.getByRole('tab', {name: `${theme === 'dark' ? 'Dark' : 'Light'} theme`, exact: true}).click();
        await page.waitForTimeout(2500);
        const rectangles = [];
        for (const [target, label] of [['A', 'High'], ['B', 'Mean']]) {
          const rect = await page.locator(`svg [role="button"][aria-label^="${label} target"] circle`).first().boundingBox();
          if (!rect) throw Error(`Missing source ${label} dot`);
          config.targets[target] = {x: rect.x + rect.width / 2, y: rect.y + rect.height / 2};
          rectangles.push({target, label, rect});
        }
        config.provenance.observedTouchTargets = rectangles;
        await page.close();
      }
      config.provenance.inputTransport = 'Shared click actions translated to actual touchscreen.tap by chart-only wrapper. No synthetic DOM pointer dispatch.';
      config.provenance.touchWrapperSha256 = wrapperSha256;
      config.provenance.touchObservation = 'observed-touch.json';
      config.provenance.keyboardMethod = 'None in touch sequence. Keyboard coverage is in separate final-v9 recordings.';
      config.events = [
        {atMs: 300, type: 'click', target: 'A', caption: 'Trusted touch A. High target.'},
        {atMs: 1100, type: 'click', target: 'A', caption: 'Second trusted touch A toggles the source target off.'},
        {atMs: 1900, type: 'click', target: 'A', caption: 'Third trusted touch A toggles it on again.'},
        {atMs: 2200, type: 'click', target: 'B', caption: 'Trusted touch B. Mean target.'},
        {atMs: 2320, type: 'click', target: 'A', caption: 'Trusted touch A interrupts the animated header.'},
      ];
      config.finalHoldMs = 700;
      await writeFile(`${output}/${reference ? 'reference' : 'after'}-price-target-fan-touch-${theme}-${preference}.json`, JSON.stringify(config, null, 2), {flag: 'wx'});
    }
  }
} finally {await browser.close();}
