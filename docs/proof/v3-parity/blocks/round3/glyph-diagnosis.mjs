import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const output = path.join(import.meta.dirname, process.argv[2]);
const expected = '1053446b12eb61b657eee4f2ac55ebc47df0a41261081be8dcd46916a465849f';
const servedUrl = 'http://127.0.0.1:8108/main.dart.js';
const recorder = '/Users/codenameakshay/.t3/worktrees/beui/t3-f7137276/tool/parity_capture.mjs';
const runtime = '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const actual = sha(Buffer.from(await (await fetch(servedUrl)).arrayBuffer()));
assert.equal(actual, expected);
await mkdir(output);
await writeFile(path.join(output, 'served-build.json'), JSON.stringify({ expected, actual, servedUrl, recorderSha256: sha(await readFile(recorder)), checkedAt: new Date().toISOString(), revision: 'e5930c376a1f1d54d542e623677049faef6a2b69' }, null, 2));
const original = JSON.parse(await readFile(path.join(import.meta.dirname, '../round2/press-reduced/candidate-dark-reduce-config.json')));
const configPath = path.join(output, 'same-hash-config.json');
await writeFile(configPath, JSON.stringify(original, null, 2));
const capture = spawnSync(process.execPath, [recorder, configPath, path.join(output, 'same-hash-recorder')], { env: { ...process.env, PARITY_PLAYWRIGHT: runtime }, encoding: 'utf8', timeout: 180000 });
await writeFile(path.join(output, 'same-hash-recorder.log'), `${capture.stdout}\n${capture.stderr}\nexit=${capture.status}\n`);
assert.equal(capture.status, 0);
assert.equal(sha(Buffer.from(await (await fetch(servedUrl)).arrayBuffer())), expected);
const { chromium } = await import(runtime);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
try {
  const page = await browser.newPage({ viewport: original.viewport, deviceScaleFactor: 1, colorScheme: 'dark', reducedMotion: 'reduce' });
  const requests = [];
  const errors = [];
  page.on('response', response => {
    if (/font|\.ttf|\.otf|main.dart.js/i.test(response.url())) requests.push({ at: Date.now(), url: response.url(), status: response.status() });
  });
  page.on('requestfailed', request => errors.push({ url: request.url(), error: request.failure() }));
  page.on('pageerror', error => errors.push({ error: String(error) }));
  await page.goto(original.url, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3500);
  await page.evaluate(() => document.fonts.ready);
  const cdp = await page.context().newCDPSession(page);
  async function snapshot(name) {
    const shot = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    await writeFile(path.join(output, `${name}-cdp.png`), Buffer.from(shot.data, 'base64'));
    await page.screenshot({ path: path.join(output, `${name}-playwright.png`) });
    await writeFile(path.join(output, `${name}-state.json`), JSON.stringify(await page.evaluate(() => ({ probe: globalThis.__beuiCapture, fonts: [...document.fonts].map(f => ({ family: f.family, status: f.status })), resources: performance.getEntriesByType('resource').filter(r => /font|\.ttf|\.otf/.test(r.name)).map(r => ({ name: r.name, startTime: r.startTime, responseEnd: r.responseEnd, transferSize: r.transferSize })) })), null, 2));
  }
  await snapshot('initial');
  await page.waitForTimeout(6000);
  await snapshot('wait-only');
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(500);
  await snapshot('semantics-enabled');
  await writeFile(path.join(output, 'network.json'), JSON.stringify({ requests, errors }, null, 2));
} finally { await browser.close(); }
