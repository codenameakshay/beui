import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const output = path.join(import.meta.dirname, process.argv[2]);
const expected = process.env.EXPECTED_JS_SHA256;
assert(expected);
const servedUrl = 'http://127.0.0.1:8108/main.dart.js';
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const actual = sha(Buffer.from(await (await fetch(servedUrl)).arrayBuffer()));
assert.equal(actual, expected);
await mkdir(output);
const recorder = '/Users/codenameakshay/.t3/worktrees/beui/t3-f7137276/tool/parity_capture.mjs';
const runtime = '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
await writeFile(path.join(output, 'served-build.json'), JSON.stringify({ expected, actual, checkedAt: new Date().toISOString(), recorderSha256: sha(await readFile(recorder)), revision: process.env.BUILD_REVISION }, null, 2));
const { chromium } = await import(runtime);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
try {
  for (const reference of (process.env.REFERENCE === '0' ? [false] : [false, true])) {
    for (const slug of ['feedback-widget', 'card-folder']) {
      const theme = process.env.THEME || 'dark';
      const reducedMotion = process.env.REDUCED || 'no-preference';
      const name = `${reference ? 'reference' : 'candidate'}-${slug}-${theme}-${reducedMotion}`;
      const url = reference ? `https://beui.dev/components/blocks/${slug}` : `http://127.0.0.1:8108/?slug=${slug}&theme=${theme}&previewWidth=592&captureProbe=1`;
      const context = await browser.newContext({ viewport: { width: 1280, height: 1200 }, colorScheme: theme, reducedMotion, deviceScaleFactor: 1 });
      const page = await context.newPage();
      const report = { name, url, targets: {}, events: [], observations: [] };
      const button = name => page.getByRole('button', { name, exact: true }).first();
      async function save(label) { await page.screenshot({ path: path.join(output, `${name}-${label}.png`) }); }
      async function click(label, locator, atMs) {
        const box = await locator.boundingBox(); assert(box, label);
        report.targets[label] = { x: box.x + box.width / 2, y: box.y + box.height / 2, measuredBounds: box };
        report.events.push({ atMs, type: 'click', target: label });
        await page.mouse.click(report.targets[label].x, report.targets[label].y); await page.waitForTimeout(600);
      }
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded' });
        if (reference) await page.getByRole('tab', { name: `${theme === 'dark' ? 'Dark' : 'Light'} theme`, exact: true }).click();
        await page.waitForTimeout(3500);
        if (!reference) {
          await page.waitForFunction(() => !!globalThis.__beuiCapture, null, { timeout: 30000 });
          await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
          await page.waitForTimeout(500);
          report.probe = await page.evaluate(() => globalThis.__beuiCapture);
          assert.equal(report.probe.disableAnimations, reducedMotion === 'reduce');
        }
        await save('before');
        if (slug === 'feedback-widget') {
          const field = () => reference ? page.locator('textarea').first() : page.getByRole('textbox').filter({ visible: true }).last();
          await click('open', button('Help us improve'), 600);
          report.emptyDisabled = await button('Submit').isDisabled();
          await click('field', field(), 1400);
          report.events.push({ atMs: 2200, type: 'text', text: '   ' });
          await page.keyboard.insertText('   '); await page.waitForTimeout(200);
          report.whitespaceDisabled = await button('Submit').isDisabled();
          await save('whitespace');
          report.events.push({ atMs: 2900, type: 'key', key: 'ControlOrMeta+A' }, { atMs: 3100, type: 'text', text: 'A draft to discard' });
          await page.keyboard.press('ControlOrMeta+A'); await page.keyboard.insertText('A draft to discard'); await page.waitForTimeout(200);
          assert.equal(await button('Submit').isDisabled(), false);
          await save('draft');
          await click('cancel', button('Cancel'), 4000);
          await click('open', button('Help us improve'), 4900);
          report.afterCancel = await field().inputValue();
          await save('reopened');
          await click('field', field(), 5800);
          report.events.push({ atMs: 6500, type: 'text', text: 'Discard on Escape' }, { atMs: 7300, type: 'key', key: 'Escape' });
          await page.keyboard.insertText('Discard on Escape'); await page.keyboard.press('Escape'); await page.waitForTimeout(600);
          await click('open', button('Help us improve'), 8200);
          report.afterEscape = await field().inputValue();
          await save('escape-reopened');
          if (reference || process.env.EXPECT_SOURCE === '1') {
            assert.equal(report.emptyDisabled, true); assert.equal(report.whitespaceDisabled, true);
            assert.equal(report.afterCancel, ''); assert.equal(report.afterEscape, '');
          } else {
            assert.equal(report.emptyDisabled, false); assert.equal(report.whitespaceDisabled, false);
            assert.equal(report.afterCancel, 'A draft to discard');
          }
        } else {
          const privacy = label => reference ? button(label) : page.getByRole('switch', { name: label, exact: true });
          await click('privacy', privacy('Show card details'), 600);
          await save('revealed');
          await click('privacy', privacy('Hide card details'), 1500);
          await save('masked');
          await page.keyboard.press('Tab');
          await save('keyboard');
          report.events.push({ atMs: 2400, type: 'key', key: 'Tab' });
        }
        report.pass = true;
      } catch (error) { report.error = String(error.stack || error); report.pass = false; }
      await writeFile(path.join(output, `${name}-assertions.json`), JSON.stringify(report, null, 2));
      await context.close();
      assert(report.pass, report.error);
      assert.equal(sha(Buffer.from(await (await fetch(servedUrl)).arrayBuffer())), expected);
      const config = { url, viewport: { width: 1280, height: 1200 }, theme, reducedMotion, reference, requireFlutterProbe: !reference, servedJs: reference ? undefined : { url: servedUrl, sha256: expected, revision: process.env.BUILD_REVISION || 'recorded build identity' }, backend: 'screenshots', loadWaitMs: 3500, finalHoldMs: 1000, targets: report.targets, events: report.events, provenance: { source: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', liveDeploymentRevision: null, wrapper: 'd831524 previewWidth592 background 21dark/252light, captureProbe1. Original 5ec78ac untouched.', assertions: 'Separate browser run, recorded states require decoded inspection.' } };
      const file = path.join(output, `${name}-config.json`); await writeFile(file, JSON.stringify(config, null, 2));
      const run = spawnSync(process.execPath, [recorder, file, path.join(output, name)], { env: { ...process.env, PARITY_PLAYWRIGHT: runtime }, encoding: 'utf8', timeout: 180000 });
      await writeFile(path.join(output, `${name}-record.log`), `${run.stdout}\n${run.stderr}\nexit=${run.status}\n`);
      assert.equal(run.status, 0);
      console.log(name, 'passed');
    }
  }
} finally { await browser.close(); }
