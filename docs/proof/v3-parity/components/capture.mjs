import { createRequire } from 'node:module';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE ?? '/Users/codenameakshay/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const phase = process.argv[2] ?? 'before';
const root = resolve(import.meta.dirname, phase);
const slugs = (process.env.CAPTURE_SLUGS ?? 'tooltip,timeline,alert,collapsible,aspect-ratio,arc-picker,sortable-stack,morphing-lightbox,date-range-picker,card,color-picker,color-selector,breadcrumb,button-metallic,expandable-control,adaptive-stepper,combobox,multi-select,file-tree,range-slider-inline,tabs,select,table').split(',');
const candidateSlug = { 'morphing-lightbox': 'image-viewer', 'button-metallic': 'button', 'range-slider-inline': 'range-slider' };
const referenceSlug = { 'morphing-lightbox': 'image-viewer', 'button-metallic': 'button', 'range-slider-inline': 'range-slider' };
const browser = await chromium.launch({ headless: true, executablePath: process.env.CHROME_PATH ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const results = [];
for (const origin of (process.env.CAPTURE_ORIGINS ?? 'reference,candidate').split(',')) {
  for (const theme of (process.env.CAPTURE_THEMES ?? 'dark,light').split(',')) {
    for (const slug of slugs) {
      const dir = resolve(root, origin, theme, slug);
      await mkdir(dir, { recursive: true });
      const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, colorScheme: theme, reducedMotion: 'no-preference', recordVideo: { dir, size: { width: 1440, height: 1000 } } });
      await context.addInitScript(({ theme }) => {
        localStorage.setItem('theme', theme);
      }, { theme });
      const page = await context.newPage();
      const url = origin === 'reference' ? `https://beui.dev/components/motion/${referenceSlug[slug] ?? slug}` : `http://localhost:8102/?slug=${candidateSlug[slug] ?? slug}&theme=${theme}&color=blue`;
      const result = { phase, origin, theme, slug, url, viewport: { width: 1440, height: 1000 }, actions: [] };
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
        if (origin === 'candidate') {
          await page.waitForSelector('flt-semantics-placeholder', { state: 'attached' });
          await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
          await page.waitForFunction(() => document.querySelectorAll('flt-semantics[role="button"]').length > 6);
        }
        await page.waitForTimeout(1200);
        await page.screenshot({ path: resolve(dir, 'idle.png') });
        const controls = origin === 'reference' ? page.locator('main button') : page.locator('flt-semantics[role="button"], flt-semantics[role="radio"], flt-semantics[role="tab"], flt-semantics[role="checkbox"]');
        const targets = [];
        for (const control of await controls.all()) {
          const box = await control.boundingBox();
          if (!box || box.x < 280 || box.x > 1090 || box.y < 320 || box.y > 820 || box.width < 8 || box.height < 8) continue;
          const label = (await control.getAttribute('aria-label')) ?? (await control.innerText());
          if (/Preview|Code|Usage|Copy|Web|Reset preview|Full screen|Toggle|Expand preview|CLI|Manual/.test(label)) continue;
          targets.push({ control, box, label });
          if (targets.length === 3) break;
        }
        for (const [index, { box, label }] of targets.entries()) {
          const x = box.x + box.width / 2;
          const y = box.y + box.height / 2;
          await page.mouse.move(x, y);
          await page.waitForTimeout(450);
          await page.screenshot({ path: resolve(dir, `hover-${index}.png`) });
          await page.mouse.move(x + 6, y + 3);
          await page.waitForTimeout(150);
          if (slug !== 'tooltip') await page.mouse.click(x, y);
          await page.waitForTimeout(450);
          await page.screenshot({ path: resolve(dir, `active-${index}.png`) });
          result.actions.push({ label, x, y, hover: true, move: true, click: slug !== 'tooltip' });
        }
        await page.mouse.move(300, 280);
        await page.keyboard.press('Escape');
        await page.waitForTimeout(300);
        await page.screenshot({ path: resolve(dir, 'exit.png') });
        result.title = await page.title();
        result.body = (await page.locator('body').innerText()).slice(0, 16000);
      } catch (error) {
        result.error = String(error);
      }
      const video = page.video();
      await context.close();
      if (video) {
        await video.saveAs(resolve(dir, 'recording.webm'));
        await video.delete();
        result.video = resolve(dir, 'recording.webm');
      }
      await writeFile(resolve(dir, 'capture.json'), JSON.stringify(result, null, 2));
      results.push(result);
      console.log(JSON.stringify({ origin, theme, slug, actions: result.actions, error: result.error }));
    }
  }
}
await writeFile(resolve(root, 'manifest.json'), JSON.stringify({ baseline: '5ec78ac30e1274727ddd185a883346e4d908e6c8', referenceRevision: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', capturedAt: new Date().toISOString(), results }, null, 2));
await browser.close();
