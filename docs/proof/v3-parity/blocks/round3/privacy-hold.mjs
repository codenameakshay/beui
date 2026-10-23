import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const output = path.join(root, process.argv[2]);
const expected = process.env.EXPECTED_JS_SHA256;
assert(expected);
const scriptUrl = 'http://127.0.0.1:8108/main.dart.js';
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
assert.equal(sha(Buffer.from(await (await fetch(scriptUrl)).arrayBuffer())), expected);
await mkdir(output);
const recorder = '/Users/codenameakshay/.t3/worktrees/beui/t3-f7137276/tool/parity_capture.mjs';
const runtime = '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const reference = process.env.REFERENCE === '1';
const theme = process.env.THEME || 'dark';
const reducedMotion = process.env.REDUCED || 'no-preference';
const before = process.env.EXPECT_CANCEL === '1';
const url = reference ? 'https://beui.dev/components/blocks/card-folder' : `http://127.0.0.1:8108/?slug=card-folder&theme=${theme}&previewWidth=592&captureProbe=1`;
const report = { url, theme, reducedMotion, before, reference, errors: [] };
await writeFile(path.join(output, 'served-build.json'), JSON.stringify({ url: scriptUrl, expected, revision: process.env.BUILD_REVISION, recorderSha256: sha(await readFile(recorder)), checkedAt: new Date().toISOString() }, null, 2));
const { chromium } = await import(runtime);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 1200 }, colorScheme: theme, reducedMotion, deviceScaleFactor: 1 });
  page.on('pageerror', error => report.errors.push(String(error)));
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  if (reference) {
    await page.getByRole('tab', { name: `${theme === 'dark' ? 'Dark' : 'Light'} theme`, exact: true }).click();
  } else {
    await page.waitForFunction(() => !!globalThis.__beuiCapture, null, { timeout: 30000 });
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    report.probe = await page.evaluate(() => globalThis.__beuiCapture);
    assert.equal(report.probe.disableAnimations, reducedMotion === 'reduce');
  }
  await page.waitForTimeout(3500);
  const privacy = label => page.getByRole(reference ? 'button' : 'switch', { name: label, exact: true }).first();
  const box = await privacy('Show card details').boundingBox();
  assert(box);
  report.targets = { privacy: { x: box.x + box.width / 2, y: box.y + box.height / 2, measuredBounds: box } };
  await page.mouse.move(report.targets.privacy.x, report.targets.privacy.y);
  await page.mouse.down();
  report.downAt = Date.now();
  await page.waitForTimeout(750);
  await page.screenshot({ path: path.join(output, 'held.png') });
  report.releasedAt = Date.now();
  await page.mouse.up();
  await page.waitForTimeout(600);
  report.revealedAfterRelease = await privacy('Hide card details').count() === 1;
  await page.screenshot({ path: path.join(output, 'released.png') });
  assert.equal(report.revealedAfterRelease, !before);
  if (!before) {
    await page.keyboard.press('Enter');
    await page.waitForTimeout(600);
    report.hiddenAfterEnter = await privacy('Show card details').count() === 1;
    assert.equal(report.hiddenAfterEnter, true);
    await page.screenshot({ path: path.join(output, 'keyboard.png') });
  }
  assert.deepEqual(report.errors, []);
  report.pass = true;
} finally {
  await writeFile(path.join(output, 'assertions.json'), JSON.stringify(report, null, 2));
  await browser.close();
}
assert.equal(sha(Buffer.from(await (await fetch(scriptUrl)).arrayBuffer())), expected);
const events = [{ atMs: 600, type: 'move', target: 'privacy' }, { atMs: 900, type: 'down' }, { atMs: 1650, type: 'up' }];
if (!before) events.push({ atMs: 2600, type: 'key', key: 'Enter' });
const config = { url, viewport: { width: 1280, height: 1200 }, theme, reducedMotion, reference, requireFlutterProbe: !reference,
  servedJs: reference ? undefined : { url: scriptUrl, sha256: expected, revision: process.env.BUILD_REVISION }, backend: 'screenshots', loadWaitMs: 3500, finalHoldMs: 1000, targets: report.targets, events,
  provenance: { source: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', liveDeploymentRevision: null, wrapper: 'd831524 width592 captureProbe1. Original baseline untouched.', dependency: process.env.TOOLTIP_DEPENDENCY || 'parent pre-12155d8e blob d12867eac1ed7a24e1708448f079161cebe12482', limitation: 'Separate observed behavioral run. Decoded recording state inspection also required. No exact timing or 60fps claim.' } };
const file = path.join(output, 'config.json');
await writeFile(file, JSON.stringify(config, null, 2));
const run = spawnSync(process.execPath, [recorder, file, path.join(output, 'recording')], { env: { ...process.env, PARITY_PLAYWRIGHT: reference ? runtime : path.join(root, 'font-observer.mjs'), FONT_PROOF_FILE: path.join(output, 'font-responses.json') }, encoding: 'utf8', timeout: 180000 });
await writeFile(path.join(output, 'record.log'), `${run.stdout}\n${run.stderr}\nexit=${run.status}\n`);
assert.equal(run.status, 0);
