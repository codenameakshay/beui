import { createRequire } from 'node:module';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH || '/Users/codenameakshay/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const phase = process.argv[2] || 'before';
const root = path.resolve(import.meta.dirname, phase);
const slugs = (process.env.SLUGS || 'project-folder,card-folder,morphing-search,morphing-search-chips,morphing-tabs,prediction-market-card,signup-form').split(',');
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const report = [];
for (const target of (process.env.TARGETS || 'reference,candidate').split(',')) {
  for (const slug of slugs) {
    const directory = path.join(root, target, slug);
    await mkdir(directory, { recursive: true });
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 1, colorScheme: 'dark', recordVideo: { dir: directory, size: { width: 1280, height: 900 } } });
    const page = await context.newPage();
    const sourcePage = slug === 'morphing-search-chips' ? 'morphing-search' : slug === 'prediction-market-card' ? 'prediction-market' : slug;
    const family = ['dock', 'text-animation', 'number'].includes(slug) ? 'components' : 'blocks';
    const url = target === 'reference' ? `https://beui.dev/components/${family === 'components' ? 'motion/' : 'blocks/'}${sourcePage}` : `${process.env.CANDIDATE_URL || 'http://localhost:8103'}/?slug=${slug}&theme=dark${process.env.PREVIEW_WIDTH ? `&previewWidth=${process.env.PREVIEW_WIDTH}` : ''}`;
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    try {
      const response = await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
      if (!response?.ok()) throw new Error(`HTTP ${response?.status()} at ${page.url()}`);
      if (target === 'candidate') {
        await page.locator('flt-glass-pane').waitFor({ state: 'attached', timeout: 45000 });
        await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
      }
      await page.waitForTimeout(1800);
      await page.screenshot({ path: path.join(directory, 'rest.png') });
      await writeFile(path.join(directory, 'dom.txt'), await page.locator('body').innerText());
      await writeFile(path.join(directory, 'elements.json'), JSON.stringify(await page.locator('button,input,[role="button"],[role="tab"],[data-slot]').evaluateAll(elements => elements.map(e => { const r = e.getBoundingClientRect(); return { tag: e.tagName, role: e.getAttribute('role'), slot: e.getAttribute('data-slot'), label: e.getAttribute('aria-label'), text: e.textContent?.slice(0, 100), x: r.x, y: r.y, width: r.width, height: r.height }; })), null, 2));
      report.push({ target, slug, url, errors });
    } catch (error) {
      report.push({ target, slug, url, error: String(error), errors });
    }
    await context.close();
    await page.video()?.saveAs(path.join(directory, 'mount.webm'));
  }
}
await browser.close();
await writeFile(path.join(root, 'report.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
