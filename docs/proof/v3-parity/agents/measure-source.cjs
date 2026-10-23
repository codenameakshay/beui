const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/tmp/beui-agents-capture/node_modules/playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const inventory = require('./route-inventory.json');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1, colorScheme: 'dark', locale: 'en-US', timezoneId: 'Asia/Kolkata' });
  const page = await context.newPage();
  const measurements = [];
  for (const route of inventory.routes.filter(route => route.sourceUrl)) {
    try {
      await page.goto(route.sourceUrl, { waitUntil: 'networkidle', timeout: 60000 });
      await page.getByRole('tab', { name: 'Dark theme', exact: true }).click();
      await page.waitForTimeout(1000);
      const geometry = await page.evaluate(() => {
        const describe = element => ({ tag: element.tagName, slot: element.getAttribute('data-slot'), className: element.className, rect: element.getBoundingClientRect().toJSON() });
        return {
          viewport: { width: innerWidth, height: innerHeight, dpr: devicePixelRatio },
          dark: document.documentElement.classList.contains('dark'),
          stages: [...document.querySelectorAll('[aria-label="Expand preview"]')].map(button => {
            const stage = document.getElementById(button.getAttribute('aria-controls'));
            return stage && { id: stage.id, ...describe(stage), children: [...stage.children].map(child => ({ ...describe(child), children: [...child.children].map(describe) })) };
          }),
        };
      });
      measurements.push({ route: route.id, url: route.sourceUrl, measuredAt: new Date().toISOString(), ...geometry });
      console.log(route.slug, geometry.stages.map(stage => stage?.rect.width));
    } catch (error) {
      measurements.push({ route: route.id, error: String(error) });
      console.log(route.slug, String(error));
    }
  }
  await fs.writeFile(path.join(__dirname, 'source-geometry.json'), JSON.stringify({ referenceRevision: inventory.source, liveDeploymentRevision: 'unknown', timing: 'Supplemental measurements after captures. Not measurements at original recording time.', candidateCondition: 'Unchanged visual_harness.dart, 48px outer padding. previewWidth is ignored. No matched-stage-width verdict.', measurements }, null, 2));
  const rows = measurements.map(measurement => `| ${measurement.route} | ${measurement.stages?.filter(Boolean).map(stage => stage.rect.width).join(', ') ?? 'error'} | ${measurement.stages?.filter(Boolean).map(stage => stage.children.filter(child => child.rect.width > 0).map(child => `${child.rect.width} × ${child.rect.height}`).join(' + ')).join('; ') ?? measurement.error} |`);
  await fs.writeFile(path.join(__dirname, 'SOURCE_GEOMETRY.md'), `# Supplemental source geometry\n\nThese live measurements follow the original recordings. They do not retroactively establish matching capture geometry. The viewport is 1440 × 1000 at DPR 1 with dark theme. Source checkout revision is ${inventory.source}, but the live deployment revision is unknown. Separate stages appear in DOM order. Child bounds include preview wrappers and are not necessarily the innermost widget size.\n\n| Route | Stage widths in px | Immediate visible child bounds in px |\n|---|---|---|\n${rows.join('\n')}\n\nThe candidate recordings use the unchanged visual_harness entrypoint and its 48px outer padding, not the explorer shell. previewWidth is ignored. No baseline wrapper or shared-width commit was applied. Source AI Sidebar and Chat App wrappers include 12px padding on each side. Their inner widths are 728px at this viewport. Hidden or missing stage targets remain in the raw JSON rather than counting as geometry evidence.\n`);
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
