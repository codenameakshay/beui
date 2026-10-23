import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('./', import.meta.url));
const output = `${root}favicon-runtime${process.argv[2] ? `-${process.argv[2]}` : ''}`;
await mkdir(output);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const phase = process.argv[3] ?? 'favicons';
const expected = hash(await readFile(`example/build/agents-round2-${phase}/main.dart.js`));
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const records = [];
try {
  for (const mode of ['live', 'fixture-success', 'fixture-error']) {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
    const page = await context.newPage();
    await page.addInitScript(mode => {
      const descriptor = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
      globalThis.__providerImageAssignments = [];
      Object.defineProperty(HTMLImageElement.prototype, 'src', {
        ...descriptor,
        set(value) {
          if (/favicon\.ico/.test(value)) {
            globalThis.__providerImageAssignments.push({ url: value, referrerPolicy: this.referrerPolicy });
            if (mode === 'fixture-success') value = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="red"/></svg>');
            if (mode === 'fixture-error') value = 'data:image/png,not-a-png';
          }
          descriptor.set.call(this, value);
        },
      });
    }, mode);
    const requests = [];
    const scripts = [];
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    context.on('request', request => {
      if (/favicon\.ico/.test(request.url())) requests.push({ url: request.url(), headers: request.headers() });
    });
    page.on('response', async response => {
      if (response.url().endsWith('/main.dart.js')) scripts.push(hash(await response.body()));
    });
    const url = `http://127.0.0.1:18107/agents-round2-${phase}/?slug=prompt-input&previewWidth=752&captureProbe=1`;
    assert.equal(hash(Buffer.from(await (await fetch(new URL('main.dart.js', url))).arrayBuffer())), expected);
    await page.goto(url, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(1000);
    assert(scripts.includes(expected), 'browser loaded a different main.dart.js');
    await page.getByRole('button', { name: 'GPT-5.2', exact: true }).click();
    await page.waitForTimeout(1500);
    const images = await page.locator('img').evaluateAll(nodes => nodes.map(image => ({
      src: image.src, referrerPolicy: image.referrerPolicy,
      complete: image.complete, naturalWidth: image.naturalWidth,
      rect: image.getBoundingClientRect().toJSON(),
    })));
    const aria = await page.locator('body').ariaSnapshot();
    const assignments = await page.evaluate(() => globalThis.__providerImageAssignments);
    await writeFile(`${output}/${mode}-observed.json`, JSON.stringify({ images, requests, assignments, aria, errors, html: await page.content() }, null, 2));
    await page.screenshot({ path: `${output}/${mode}.png` });
    assert(assignments.length >= 5, 'provider favicon sources were not assigned');
    assert(assignments.every(request => request.referrerPolicy === 'no-referrer'), 'no-referrer was not set before assigning the remote source');
    if (mode === 'fixture-success') {
      assert(images.length >= 5, 'picker lacks all five provider images');
      assert(images.every(image => image.complete && image.naturalWidth === 16 && image.referrerPolicy === 'no-referrer'));
    }
    if (mode === 'fixture-error') assert.equal(images.length, 0, 'decode failure did not replace images with Bot');
    await page.getByRole('button', { name: 'Claude Sonnet 4', exact: true }).click();
    await page.waitForTimeout(300);
    const selectedModelAria = await page.locator('body').ariaSnapshot();
    assert(selectedModelAria.includes('button "Claude Sonnet 4"'), 'provider selection did not update the trigger');
    assert(!selectedModelAria.includes('Grok 4.5'), 'picker remained open after selecting a provider');
    await page.screenshot({ path: `${output}/${mode}-selected.png` });
    await page.screenshot({ path: `${output}/${mode}.png` });
    records.push({ mode, url, sha256: expected, requests, assignments, images, aria, selectedModelAria, requestHeaderVerdict: 'Detached platform image loads were not emitted as Playwright request events. Policy checked before src assignment. No request-header observation claim.' });
    await writeFile(`${output}/results.json`, JSON.stringify(records, null, 2));
    await context.close();
  }
} finally {
  await browser.close();
}
console.log('Live favicon requests inspected. Five-provider success, no-referrer, and decode-failure fallback assertions passed.');
