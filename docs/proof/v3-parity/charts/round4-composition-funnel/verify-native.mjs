import assert from 'node:assert/strict';
import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const out = `${root}/${process.argv[2]}`;
await mkdir(out);
const revision = process.argv[3];
const candidateBuild = process.argv[4];
assert(revision && candidateBuild);
const browser = await chromium.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
const rows = [];
const failures = [];
try {
  for (const source of [true, false]) {
    for (const reducedMotion of ['no-preference', 'reduce']) {
      for (const slug of ['composition-chart', 'funnel-chart']) {
        for (const input of ['mouse-keyboard', 'touch']) {
          const id = `${source ? 'source' : 'candidate'}-${slug}-${reducedMotion}-${input}`;
          const page = await browser.newPage({viewport: {width: 1000, height: 1400}, reducedMotion, hasTouch: input === 'touch'});
          const scripts = [];
          const pending = [];
          page.on('response', response => {
            if (/\.m?js(?:\?|$)/.test(response.url())) pending.push(response.body().then(bytes => scripts.push({url: response.url(), sha256: createHash('sha256').update(bytes).digest('hex')})));
          });
          const url = `http://127.0.0.1:18116/${source ? 'source/' : ''}?slug=${slug}&previewWidth=752&captureProbe=1`;
          const states = [];
          const readout = () => page.evaluate(({source, slug}) => {
            if (source) return [...document.querySelectorAll('[role="tooltip"]')].filter(e => getComputedStyle(e).visibility !== 'hidden').map(e => e.textContent).join('\n');
            return [...document.querySelectorAll('flt-semantics')].filter(e => !e.querySelector('flt-semantics')).map(e => e.textContent).filter(text => slug === 'composition-chart' ? /Organic search\n[\d,]+ visits/.test(text) : /from previous stage/.test(text)).join('\n');
          }, {source, slug});
          const check = async (name, expected) => {
            await page.waitForTimeout(450);
            const text = await readout();
            const screenshot = `${id}-${name}.png`;
            await page.screenshot({path: `${out}/${screenshot}`});
            const pass = expected === null ? text === '' : text.includes(expected);
            states.push({name, expected, text, pass, screenshot});
            if (!pass) failures.push(`${id} ${name}: expected ${JSON.stringify(expected)}, received ${JSON.stringify(text)}`);
          };
          try {
            await page.goto(url);
            await page.waitForTimeout(4500);
            await page.evaluate(() => document.fonts.ready);
            if (!source) await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
            await page.waitForTimeout(400);
            await Promise.all(pending);
            const build = source ? '/tmp/beui-round4-composition-funnel-source-v3-20261023/source.js' : `${candidateBuild}/main.dart.js`;
            const expectedHash = createHash('sha256').update(await readFile(build)).digest('hex');
            assert(scripts.some(script => script.sha256 === expectedHash));
            const motion = await page.evaluate(() => ({browser: matchMedia('(prefers-reduced-motion: reduce)').matches, flutter: globalThis.__beuiCapture ?? null}));
            assert.equal(motion.browser, reducedMotion === 'reduce');
            if (!source) assert.equal(motion.flutter.disableAnimations, reducedMotion === 'reduce');
            let bounds;
            if (slug === 'composition-chart') bounds = source ? await page.locator('main svg').first().boundingBox() : await page.getByRole('slider').first().evaluate(e => e.parentElement.getBoundingClientRect().toJSON());
            else bounds = await page.getByRole('button', {name: /^Signed up: /}).boundingBox();
            assert(bounds);
            const a = {x: bounds.x + bounds.width * .2, y: bounds.y + bounds.height * .3};
            const b = {x: bounds.x + bounds.width * .7, y: bounds.y + bounds.height * .7};
            await check('rest', null);
            if (input === 'touch') {
              for (let tap = 1; tap <= 3; tap++) {
                await page.touchscreen.tap(a.x, a.y);
                await check(`tap-${tap}`, slug === 'composition-chart' ? null : tap === 2 ? null : '65.0% from previous stage');
              }
              if (slug === 'composition-chart') {
                const cdp = await page.context().newCDPSession(page);
                await cdp.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{x: a.x, y: a.y}]});
                await check('touch-held-a', 'Aug 8');
                await cdp.send('Input.dispatchTouchEvent', {type: 'touchMove', touchPoints: [{x: b.x, y: a.y}]});
                await check('touch-drag-b', 'Aug 26');
                await cdp.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
                await check('touch-release', null);
              } else {
                const box = await page.getByRole('button', {name: /^Started trial: /}).boundingBox();
                await page.touchscreen.tap(box.x + box.width / 2, box.y + box.height / 2);
                await check('tap-b', '30.0% of starting total');
              }
            } else if (slug === 'composition-chart') {
              await page.mouse.move(a.x, a.y);
              await check('hover-a', 'Aug 8');
              await page.mouse.move(b.x, b.y);
              await check('hover-b', 'Aug 26');
              await page.mouse.click(b.x, b.y);
              await check('click-b', 'Aug 26');
              await page.mouse.move(10, 10);
              await check('exit', null);
              await page.keyboard.press('ArrowLeft');
              await check('left', 'Aug 25');
              await page.keyboard.press('Escape');
              await check('escape', null);
              await page.keyboard.press('Home');
              await check('home', 'Aug 1');
              await page.keyboard.press('End');
              await check('end', 'Sep 5');
              await page.keyboard.press('Tab');
              await check('legend-focus', null);
            } else {
              await page.mouse.move(a.x, a.y);
              await check('hover', '65.0% from previous stage');
              await page.mouse.click(a.x, a.y);
              await check('click-dismiss', null);
              await page.mouse.move(10, 10);
              await page.keyboard.press('Tab');
              await check('native-tab', '45.0% of starting total');
              await page.keyboard.press('Escape');
              await check('escape', null);
              await page.getByRole('button', {name: 'Next cohort', exact: true}).click();
              await page.waitForTimeout(100);
              await page.getByRole('button', {name: 'Next cohort', exact: true}).click();
              await page.waitForTimeout(400);
              assert(await page.getByRole('button', {name: /^Subscribed: 2,376 people, 10.8%/}).count());
              await page.getByRole('button', {name: 'Horizontal', exact: true}).click();
              await page.waitForTimeout(400);
              const horizontal = await page.getByRole('button', {name: /^Visitors: /}).boundingBox();
              assert.equal(horizontal.height, 300);
              assert(Math.abs(horizontal.width - 150.4) < .1);
              await check('horizontal', null);
              await page.getByRole('button', {name: 'Vertical', exact: true}).click();
              await page.waitForTimeout(400);
              const vertical = await page.getByRole('button', {name: /^Visitors: /}).boundingBox();
              assert.equal(vertical.height, 72);
              await check('vertical', null);
              states.push({name: 'cohort-interruption-and-direction', pass: true, horizontal, vertical});
            }
            rows.push({id, url, revision: source ? 'a76e57c9bbc2837e96420b2610e9c82a3271bb05' : revision, expectedHash, scripts, motion, bounds, states, pass: states.every(state => state.pass)});
          } catch (error) {
            failures.push(`${id}: ${error.stack}`);
            rows.push({id, url, states, pass: false, error: String(error)});
          } finally {
            await page.close();
            await writeFile(`${out}/states.json`, JSON.stringify({rows, failures}, null, 2));
          }
        }
      }
    }
  }
} finally {
  await browser.close();
}
console.log(JSON.stringify({cases: rows.length, passed: rows.filter(row => row.pass).length, failures}, null, 2));
assert.equal(failures.length, 0);
