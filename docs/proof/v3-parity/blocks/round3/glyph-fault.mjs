import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const output = path.join(import.meta.dirname, process.argv[2]);
const expected = process.env.EXPECTED_JS_SHA256;
const actual = createHash('sha256').update(Buffer.from(await (await fetch('http://127.0.0.1:8108/main.dart.js')).arrayBuffer())).digest('hex');
assert.equal(actual, expected);
await mkdir(output);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const requests = [];
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 1200 }, colorScheme: 'dark', reducedMotion: 'reduce', deviceScaleFactor: 1 });
  await page.route(/lucide\.ttf|GeistMono-.*\.ttf/, route => { requests.push(route.request().url()); return route.abort('failed'); });
  await page.goto('http://127.0.0.1:8108/?slug=card-folder&theme=dark&previewWidth=592&captureProbe=1');
  await page.waitForTimeout(3500);
  await page.screenshot({ path: path.join(output, 'font-failure.png') });
  await writeFile(path.join(output, 'fault.json'), JSON.stringify({ expected, actual, requests, fault: 'Abort only Lucide and Geist Mono font requests. This is an induced diagnosis, not the historical recording.', probe: await page.evaluate(() => globalThis.__beuiCapture) }, null, 2));
  assert(requests.some(url => url.endsWith('lucide.ttf')));
} finally { await browser.close(); }
