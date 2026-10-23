import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = import.meta.dirname;
const inventory = JSON.parse(await readFile(join(root, 'inventory.json'), 'utf8'));
const output = join(root, 'release-measurements-run3');
await mkdir(output);
const browser = await chromium.launch({
  headless: true,
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
});
const results = [];
try {
  for (const route of inventory.routes) {
    const slug = route.id.split('/')[1];
    const result = { slug, sourceUrl: route.sourceUrl, viewport: { width: 1280, height: 1000 }, theme: 'light' };
    for (const origin of ['reference', 'candidate']) {
      const context = await browser.newContext({ viewport: result.viewport, colorScheme: 'light', reducedMotion: 'no-preference' });
      const page = await context.newPage();
      try {
        const width = result.reference?.stage?.width;
        const url = origin === 'reference' ? route.sourceUrl : `http://localhost:8102/?slug=${slug}&theme=light&color=blue${width ? `&previewWidth=${width}` : ''}`;
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
        if (origin === 'reference') await page.getByRole('tab', { name: 'Light theme', exact: true }).click();
        await page.waitForTimeout(origin === 'reference' ? 1500 : 4500);
        if (origin === 'candidate') {
          await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
          await page.waitForTimeout(200);
        }
        result[origin] = await page.evaluate(origin => {
          const stage = origin === 'reference' ? [...document.querySelectorAll('main div')].find(el => el.className.includes('min-h-[') && el.className.includes('justify-center')) : null;
          const bounds = el => { const r = el.getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: r.height }; };
          const box = stage && bounds(stage);
          const elements = origin === 'reference' ? [...(stage?.querySelectorAll('button,input,[role="radio"],[role="option"],[role="slider"],a') ?? [])] : [...document.querySelectorAll('flt-semantics[role]')];
          return {
            url: location.href, stage: box,
            controls: elements.map(el => ({
              tag: el.tagName, role: el.getAttribute('role'),
              name: el.getAttribute('aria-label') || el.textContent?.trim(),
              disabled: el.hasAttribute('disabled') || el.getAttribute('aria-disabled') === 'true',
              ...bounds(el),
            })).filter(el => el.width > 3 && el.height > 3 && (origin === 'reference' || (el.x > 300 && el.x < 1100 && el.y > 310 && el.y < 870))),
            images: [...document.images].map(el => ({ src: el.currentSrc, complete: el.complete, naturalWidth: el.naturalWidth })),
            body: document.body.innerText.slice(-2000),
          };
        }, origin);
        await page.screenshot({ path: join(output, `${slug}-${origin}.png`) });
      } catch (error) { result[origin] = { error: String(error) }; }
      await context.close();
    }
    results.push(result);
    await writeFile(join(output, 'measurements.json'), JSON.stringify(results, null, 2));
    console.log(JSON.stringify({ slug, width: result.reference?.stage?.width, reference: result.reference?.controls?.map(c => c.name), candidate: result.candidate?.controls?.map(c => c.name), error: result.reference?.error || result.candidate?.error }));
  }
} finally { await browser.close(); }
