import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const output = path.join(import.meta.dirname, process.argv[2]);
const expected = process.env.EXPECTED_JS_SHA256;
assert(expected);
const scriptUrl = 'http://127.0.0.1:8108/block-probe/main.dart.js';
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const actual = sha(Buffer.from(await (await fetch(scriptUrl)).arrayBuffer()));
assert.equal(actual, expected);
await mkdir(output);
const recorder = '/Users/codenameakshay/.t3/worktrees/beui/t3-f7137276/tool/parity_capture.mjs';
const runtime = '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const theme = process.env.THEME || 'dark';
const reducedMotion = process.env.REDUCED || 'no-preference';
await writeFile(path.join(output, 'served-build.json'), JSON.stringify({ expected, actual, scriptUrl, recorderSha256: sha(await readFile(recorder)), checkedAt: new Date().toISOString() }, null, 2));
const url = `http://127.0.0.1:8108/block-probe/?theme=${theme}&captureProbe=1`;
const report = { targets: {}, events: [], errors: [] };
const { chromium } = await import(runtime);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 1200 }, reducedMotion, colorScheme: theme, deviceScaleFactor: 1 });
  page.on('pageerror', error => report.errors.push(String(error)));
  await page.goto(url); await page.waitForTimeout(3500);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await page.waitForTimeout(500);
  report.probe = await page.evaluate(() => globalThis.__beuiCapture);
  assert.equal(report.probe.disableAnimations, reducedMotion === 'reduce');
  const action = page.getByRole('button', { name: 'Open actions for Enabled fixture', exact: true });
  const privacy = page.getByRole('switch', { name: 'Show card details', exact: true }).first();
  async function target(name, locator) { const b = await locator.boundingBox(); assert(b); report.targets[name] = { x: b.x + b.width / 2, y: b.y + b.height / 2, measuredBounds: b }; }
  await target('action', action); await target('privacy', privacy);
  await target('disabledAction', page.getByRole('button', { name: 'Open actions for Disabled fixture', exact: true }));
  await target('disabledPrivacy', page.getByRole('switch', { name: 'Show card details', exact: true }).last());
  await page.screenshot({ path: path.join(output, 'rest.png') });
  await page.mouse.move(report.targets.action.x, report.targets.action.y); await page.mouse.down();
  await page.waitForTimeout(800); await page.screenshot({ path: path.join(output, 'action-held.png') }); await page.mouse.up();
  await page.waitForTimeout(500); await page.keyboard.press('Enter'); await page.waitForTimeout(500);
  report.afterAction = await page.getByText('Actions: 2. Revealed: false. Disabled callbacks: 0.', { exact: true }).count();
  assert.equal(report.afterAction, 1);
  await page.screenshot({ path: path.join(output, 'action-keyboard.png') });
  await page.mouse.click(report.targets.privacy.x, report.targets.privacy.y); await page.waitForTimeout(500); await page.keyboard.press('Enter'); await page.waitForTimeout(500);
  for (const key of ['disabledAction', 'disabledPrivacy']) { await page.mouse.click(report.targets[key].x, report.targets[key].y); await page.waitForTimeout(200); }
  report.afterDisabled = await page.getByText('Actions: 2. Revealed: false. Disabled callbacks: 0.', { exact: true }).count();
  assert.equal(report.afterDisabled, 1);
  await page.screenshot({ path: path.join(output, 'disabled-and-reversed.png') });
  assert.deepEqual(report.errors, []);
  report.pass = true;
  report.events = [
    { atMs: 600, type: 'move', target: 'action' }, { atMs: 900, type: 'down' }, { atMs: 1700, type: 'up' },
    { atMs: 2400, type: 'key', key: 'Enter' }, { atMs: 3300, type: 'click', target: 'privacy' }, { atMs: 4200, type: 'key', key: 'Enter' },
    { atMs: 5100, type: 'click', target: 'disabledAction' }, { atMs: 6000, type: 'click', target: 'disabledPrivacy' },
  ];
} finally { await writeFile(path.join(output, 'assertions.json'), JSON.stringify(report, null, 2)); await browser.close(); }
assert.equal(sha(Buffer.from(await (await fetch(scriptUrl)).arrayBuffer())), expected);
const config = { url, viewport: { width: 1280, height: 1200 }, theme, reducedMotion, requireFlutterProbe: true, servedJs: { url: scriptUrl, sha256: expected, revision: process.env.BUILD_REVISION }, backend: 'screenshots', loadWaitMs: 3500, finalHoldMs: 1000, targets: report.targets, events: report.events, provenance: { fixture: 'example/lib/block_parity_probe.dart', wrapper: 'New 592px contract fixture, not the reference preview or original baseline. Decorative card artwork is a placeholder.', source: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', limitation: 'Separate behavioral assertion run. No exact image or motion parity claim.' } };
const file = path.join(output, 'config.json'); await writeFile(file, JSON.stringify(config, null, 2));
const run = spawnSync(process.execPath, [recorder, file, path.join(output, 'recording')], { env: { ...process.env, PARITY_PLAYWRIGHT: runtime }, encoding: 'utf8', timeout: 180000 });
await writeFile(path.join(output, 'record.log'), `${run.stdout}\n${run.stderr}\nexit=${run.status}\n`);
assert.equal(run.status, 0);
