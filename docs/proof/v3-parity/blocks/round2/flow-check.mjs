import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import path from 'node:path';

const output = path.join(import.meta.dirname, process.argv[2] || 'flows');
await mkdir(output);
const expected = process.env.EXPECTED_JS_SHA256;
assert(expected, 'EXPECTED_JS_SHA256 is required');
const actual = createHash('sha256').update(Buffer.from(await (await fetch('http://127.0.0.1:8108/main.dart.js')).arrayBuffer())).digest('hex');
await writeFile(path.join(output, 'served-build.json'), JSON.stringify({ expected, actual, match: expected === actual, checkedAt: new Date().toISOString(), head: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim() }, null, 2));
assert.equal(actual, expected, 'Foreign served build');
const runtime = '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const tool = '/Users/codenameakshay/.t3/worktrees/beui/t3-655688e6/tool/parity_capture.mjs';
const reducedMotion = process.env.REDUCED || 'no-preference';
const viewport = { width: 1280, height: 1200 };
const revision = `${execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()} + owned round2 dirty diff`;
await writeFile(path.join(output, 'build.diff'), execFileSync('git', ['diff', '--', 'lib', 'example/lib', 'pubspec.yaml', 'example/pubspec.yaml'], { encoding: 'utf8' }));
const toolHash = createHash('sha256').update(await readFile(tool)).digest('hex');
const { chromium } = await import(runtime);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const results = [];
try {
  for (const candidate of [true, false]) {
    for (const slug of (process.env.SLUGS || 'card-folder,feedback-widget,morphing-search-chips').split(',')) {
      for (const theme of (process.env.THEMES || 'dark').split(',')) {
        const name = `${candidate ? 'candidate' : 'reference'}-${slug}-${theme}-${reducedMotion}`;
        const sourceSlug = slug === 'morphing-search-chips' ? 'morphing-search' : slug;
        const url = candidate ? `http://127.0.0.1:8108/?slug=${slug}&theme=${theme}&previewWidth=592&captureProbe=1` : `https://beui.dev/components/blocks/${sourceSlug}`;
        const context = await browser.newContext({ viewport, colorScheme: theme, deviceScaleFactor: 1, reducedMotion });
        const page = await context.newPage();
        page.setDefaultTimeout(8000);
        const report = { name, url, checks: [], targets: {}, events: [] };
        const visible = text => candidate ? page.locator(`[aria-label=${JSON.stringify(text)}]`).first() : page.getByText(text, { exact: true }).first();
        const button = label => page.getByRole('button', { name: label, exact: true }).first();
        const save = async label => {
          await page.screenshot({ path: path.join(output, `${name}-${label}.png`) });
          report.checks.push({ label, checkedAt: new Date().toISOString() });
        };
        const click = async (label, locator, atMs) => {
          await locator.waitFor({ state: 'visible' });
          const bounds = await locator.boundingBox();
          assert(bounds && bounds.width > 0 && bounds.height > 0, label);
          assert(bounds.x + bounds.width / 2 < viewport.width && bounds.y + bounds.height / 2 < viewport.height, `Offscreen ${label}`);
          report.targets[label] = { x: bounds.x + bounds.width / 2, y: bounds.y + bounds.height / 2, measuredBounds: bounds };
          report.events.push({ atMs, type: 'click', target: label });
          await page.mouse.click(report.targets[label].x, report.targets[label].y);
          await page.waitForTimeout(650);
        };
        const key = async (key, atMs) => {
          report.events.push({ atMs, type: 'key', key });
          await page.keyboard.press(key);
          await page.waitForTimeout(650);
        };
        try {
          await page.goto(url);
          if (!candidate) await page.getByRole('tab', { name: `${theme === 'dark' ? 'Dark' : 'Light'} theme`, exact: true }).click();
          await page.waitForTimeout(3500);
          if (candidate) {
            await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
            await page.waitForTimeout(500);
            report.flutterCapture = await page.evaluate(() => globalThis.__beuiCapture);
            assert.equal(report.flutterCapture.disableAnimations, reducedMotion === 'reduce');
            assert.equal(report.flutterCapture.platformDisableAnimations, reducedMotion === 'reduce');
          }
          report.browserReducedMotion = await page.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches);
          assert.equal(report.browserReducedMotion, reducedMotion === 'reduce');
          await save('rest');
          if (slug === 'card-folder') {
            const privacy = text => candidate ? page.getByRole('switch', { name: text, exact: true }) : button(text);
            await click('privacy', privacy('Show card details'), 600);
            assert.equal(await privacy('Hide card details').count(), 1);
            await save('revealed');
            await click('privacy', privacy('Hide card details'), 1500);
            assert.equal(await privacy('Show card details').count(), 1);
            await save('masked');
            await click('folder', button('Open Saurabh Chauhan, card ending in 0806, expires 08/29'), 2400);
            assert.equal(await button('Close Saurabh Chauhan, card ending in 0806, expires 08/29').count(), 1);
            await save('opened');
            await key('Enter', 3300);
            assert.equal(await button('Open Saurabh Chauhan, card ending in 0806, expires 08/29').count(), 1);
            await save('keyboard-closed');
          } else if (slug === 'feedback-widget') {
            await click('open', button('Help us improve'), 600);
            const field = candidate ? page.getByRole('textbox').filter({ visible: true }).last() : page.locator('textarea').first();
            await click('field', field, 1500);
            const message = 'The native SVG is visible';
            report.events.push({ atMs: 2400, type: 'text', text: message });
            await page.keyboard.insertText(message);
            await page.waitForTimeout(300);
            await save('draft');
            await click('submit', button('Submit'), 3300);
            await page.waitForTimeout(1100);
            assert.equal(await button('Try again').count(), 1);
            await save('rejected');
            await click('retry', button('Try again'), 5400);
            await page.waitForTimeout(1100);
            if (candidate) assert(await page.getByText('Thanks! Your feedback helps us build something better.', { exact: true }).count());
            else assert.equal(await visible('Thanks!').count(), 1);
            await save('success');
          } else {
            const field = candidate ? page.getByRole('textbox').filter({ visible: true }).last() : page.getByPlaceholder('Search inspiration');
            await click('field', field, 600);
            await save('recents');
            report.events.push({ atMs: 1500, type: 'text', text: 'dark mode' });
            await page.keyboard.insertText('dark mode');
            await page.waitForTimeout(300);
            await save('suggestions');
            await key('Enter', 2400);
            assert.equal(await field.inputValue(), '');
            assert(await visible('dark mode').count());
            await save('chip-added');
            await key('Escape', 3300);
            await save('closed');
          }
          report.pass = true;
        } catch (error) {
          report.pass = false;
          report.error = String(error.stack || error);
          await save('failed');
          report.elements = await page.locator('[role],input,textarea').evaluateAll(es => es.map(e => ({role:e.getAttribute('role'), label:e.getAttribute('aria-label'), text:e.textContent, html:e.outerHTML.slice(0,500)})));
        }
        await context.close();
        await writeFile(path.join(output, `${name}-assertions.json`), JSON.stringify(report, null, 2));
        results.push({ name, pass: report.pass, error: report.error });
        if (report.pass && process.env.RECORD !== '0') {
          const config = { url, viewport, theme, reducedMotion, reference: !candidate, requireFlutterProbe: candidate, servedJs: candidate ? { url: 'http://127.0.0.1:8108/main.dart.js', sha256: expected, revision } : undefined, backend: 'screenshots', loadWaitMs: 3500, finalHoldMs: 1800,
            targets: report.targets, events: report.events, provenance: { expectedJsSha256: expected, tool, toolHash, source: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', liveDeploymentRevision: null, wrapper: 'd831524 source background and opt-in capture probe, previewWidth592. Old baseline untouched.', note: 'Flow assertions come from a separate observed run. Video states require independent PNG inspection. No interpolation.' } };
          const file = path.join(output, `${name}-config.json`);
          await writeFile(file, JSON.stringify(config, null, 2));
          const run = spawnSync(process.execPath, [tool, file, path.join(output, name)], { env: { ...process.env, PARITY_PLAYWRIGHT: runtime }, encoding: 'utf8', timeout: 180000 });
          await writeFile(path.join(output, `${name}-capture.log`), `${run.stdout}\n${run.stderr}\nexit=${run.status}\n`);
          if (run.status !== 0) results.at(-1).captureError = run.stderr;
        }
        await writeFile(path.join(output, 'results.json'), JSON.stringify(results, null, 2));
        console.log(name, report.pass);
      }
    }
  }
} finally { await browser.close(); }
if (results.some(r => !r.pass || r.captureError)) process.exitCode = 1;
