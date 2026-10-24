import { createRequire } from 'node:module';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH || '/Users/codenameakshay/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const phase = process.argv[2] || 'before';
const root = path.resolve(import.meta.dirname, phase, 'interactions');
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const report = [];
for (const target of (process.env.TARGETS || 'reference,candidate').split(',')) {
  for (const slug of (process.env.SLUGS || 'project-folder,card-folder,morphing-search,morphing-search-chips,morphing-tabs,prediction-market-card,signup-form').split(',')) {
    const dir = path.join(root, target, slug);
    await mkdir(dir, { recursive: true });
    const theme = process.env.THEME || 'dark';
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 1, colorScheme: theme, reducedMotion: process.env.REDUCE ? 'reduce' : 'no-preference', recordVideo: { dir, size: { width: 1280, height: 900 } } });
    const page = await context.newPage();
    page.setDefaultTimeout(5000);
    const sourceSlug = slug === 'morphing-search-chips' ? 'morphing-search' : slug === 'prediction-market-card' ? 'prediction-market' : slug;
    const family = ['dock', 'number', 'text-animation'].includes(slug) ? 'components' : 'blocks';
    const url = target === 'reference' ? `https://beui.dev/components/${family === 'components' ? 'motion/' : 'blocks/'}${sourceSlug}` : `${process.env.CANDIDATE_URL || 'http://localhost:8103'}/?slug=${slug}&theme=${theme}${process.env.PREVIEW_WIDTH ? `&previewWidth=${process.env.PREVIEW_WIDTH}` : ''}`;
    const steps = [];
    const clickCenter = async locator => { const r = await locator.boundingBox(); if (!r) throw new Error('Target has no bounds'); await page.mouse.click(r.x + r.width / 2, r.y + r.height / 2); };
    const step = async (name, action) => {
      const eventMs = await page.evaluate(() => performance.now());
      try { await action(); await page.waitForTimeout(700); await page.screenshot({ path: path.join(dir, `${steps.length}-${name}.png`) }); steps.push({ name, eventMs, result: 'captured' }); }
      catch (error) { steps.push({ name, eventMs, error: String(error) }); }
    };
    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
      if (target === 'candidate') {
        await page.locator('flt-glass-pane').waitFor({ state: 'attached', timeout: 45000 });
        await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
      }
      await page.waitForTimeout(1400);
      if (slug === 'morphing-search-chips' && target === 'reference') await page.getByRole('combobox', { name: 'Search inspiration', exact: true }).scrollIntoViewIfNeeded();
      await step('rest', async () => {});
      if (slug === 'card-folder') {
        const privacy = await page.getByRole('button', { name: 'Show card details', exact: true }).boundingBox();
        await step('privacy-reveal', () => page.getByRole('button', { name: 'Show card details', exact: true }).click());
        await step('privacy-hide', () => page.mouse.click(privacy.x + privacy.width / 2, privacy.y + privacy.height / 2));
        await step('open', () => page.getByRole('button', { name: /^Open Saurabh/ }).first().click());
        await step('close', () => page.getByRole('button', { name: /^Close Saurabh/ }).first().click());
      } else if (slug === 'project-folder') {
        const folder = target === 'reference' ? page.getByRole('button').filter({ hasText: 'Brand direction' }).first() : page.getByRole('button', { name: 'Brand direction', exact: true });
        await step('hover-enter', () => folder.hover());
        await step('hover-move', async () => { const box = await folder.boundingBox(); await page.mouse.move(box.x + box.width - 12, box.y + 20, { steps: 8 }); });
        await step('hover-leave', () => page.mouse.move(1100, 100));
        await step('open', () => folder.click());
        await step('escape', () => page.keyboard.press('Escape'));
      } else if (slug === 'morphing-tabs') {
        const general = page.getByRole('tab', { name: 'General', exact: true });
        await step('hover-enter', () => general.hover());
        await step('select', () => general.click());
        await step('keyboard-next', () => page.keyboard.press('ArrowRight'));
        await step('keyboard-reorder', () => page.keyboard.press('Alt+ArrowLeft'));
        await step('close-tab', () => page.getByRole('button', { name: 'Close Archive', exact: true }).click());
      } else if (slug === 'prediction-market-card') {
        const cta = page.getByRole('button', { name: 'Trade Celtics at 51%', exact: true });
        await step('hover-enter', () => cta.hover());
        await step('hover-leave', () => page.mouse.move(1100, 100));
        await step('keyboard-focus', () => cta.focus());
        await step('update-odds', () => page.getByRole('button', { name: 'Update odds', exact: true }).click());
      } else if (slug === 'morphing-search') {
        await step('open', () => page.getByRole('button', { name: 'Find components', exact: true }).first().click());
        await step('query', async () => { await page.keyboard.type('folder', { delay: 70 }); });
        await step('select', () => page.keyboard.press('Enter'));
        await step('escape', () => page.keyboard.press('Escape'));
      } else if (slug === 'morphing-search-chips') {
        await step('focus', () => target === 'reference' ? page.getByRole('combobox', { name: 'Search inspiration', exact: true }).click() : clickCenter(page.locator('input[aria-label="Search inspiration"]').last()));
        await step('query', () => page.keyboard.type('dark', { delay: 70 }));
        await step('add-chip', () => page.keyboard.press('Enter'));
        await step('escape', () => page.keyboard.press('Escape'));
      } else if (slug === 'signup-form') {
        await step('blur-name', async () => { await page.getByRole('textbox', { name: /^Name/ }).click(); await page.keyboard.press('Tab'); });
        await step('fix-name', async () => { await page.getByRole('textbox', { name: /^Name/ }).fill('Ada Lovelace'); await page.keyboard.press('Tab'); });
        await step('password-reveal', async () => {
          if (target === 'reference') return page.getByRole('button', { name: 'Show password', exact: true }).click();
          const r = await page.locator('input[aria-label^="Password"]').first().boundingBox();
          await page.mouse.click(r.x + r.width - 22, r.y + r.height - 28);
        });
        await step('invalid-submit', () => page.getByRole('button', { name: 'Create account', exact: true }).click());
      } else if (slug === 'notification-stack') {
        const summary = page.getByRole('button', { name: /3 notifications/ }).first();
        await step('hover-enter', () => summary.hover());
        await step('hover-leave', () => page.mouse.move(1100, 100));
        await step('expand', () => summary.click());
        await step('keyboard-exit', () => page.keyboard.press('Tab'));
      } else if (slug === 'dynamic-island') {
        for (const label of ['Call', 'Timer', 'Music', 'Dismiss']) await step(label.toLowerCase(), () => page.getByRole('button', { name: label, exact: true }).click());
      } else if (slug === 'availability-scheduler') {
        await step('toggle-day', () => page.getByRole('button', { name: 'Toggle Monday availability', exact: true }).click());
        await step('restore-day', () => page.getByRole('button', { name: 'Toggle Monday availability', exact: true }).click());
        await step('add-range', () => page.getByRole('button', { name: 'Add time range to Monday', exact: true }).click());
        await step('copy-open', () => page.getByRole('button', { name: 'Copy Monday hours to other days', exact: true }).click());
        await step('escape', () => page.keyboard.press('Escape'));
      } else if (slug === 'wallet-card') {
        await step('privacy', () => page.getByRole('button', { name: 'Hide balance', exact: true }).click());
        await step('privacy-restore', () => page.getByRole('button', { name: 'Show balance', exact: true }).click());
        await step('account-open', () => page.getByRole('button', { name: 'Main Wallet', exact: true }).click());
        await step('escape', () => page.keyboard.press('Escape'));
        await step('balance-update', () => page.getByRole('button', { name: 'Simulate balance change', exact: true }).click());
      } else if (slug === 'bloom-menu') {
        await step('open', () => page.getByRole('button', { name: /^Create/ }).first().click());
        await step('escape', () => page.keyboard.press('Escape'));
        await step('reopen', () => page.getByRole('button', { name: /^Create/ }).first().click());
        await step('outside', () => page.mouse.click(1100, 100));
      } else if (slug === 'feedback-widget') {
        await step('open', () => page.getByRole('button', { name: 'Help us improve', exact: true }).click());
        await step('escape', () => page.keyboard.press('Escape'));
        await step('reopen', () => page.getByRole('button', { name: 'Help us improve', exact: true }).click());
      } else if (slug === 'dock') {
        for (const label of ['Home', 'Music', 'Settings']) await step(`hover-${label}`, () => page.getByRole('button', { name: label, exact: true }).first().hover());
        await step('hover-leave', () => page.mouse.move(1100, 100));
      } else if (slug === 'number') {
        const animate = page.getByRole('button', { name: target === 'reference' ? 'Animate card number' : 'Animate', exact: true }).first();
        await step('animate', () => animate.click());
        await step('reverse', () => animate.click());
      } else if (slug === 'text-animation') {
        for (let i = 0; i < 3; i++) await step(`phrase-${i + 1}`, () => page.getByRole('button', { name: 'Next phrase', exact: true }).first().click());
      } else if (slug === 'knockout-bracket') {
        await step('fixture-enter', () => page.getByRole('button', { name: /Final.*Spain v Argentina/ }).first().hover());
        await step('fixture-leave', () => page.mouse.move(1100, 100));
      } else if (slug === 'infinite-masonry') {
        await step('scroll', async () => { await page.mouse.move(800, 650); await page.mouse.wheel(0, 500); });
        await step('reverse-scroll', () => page.mouse.wheel(0, -500));
      }
      await writeFile(path.join(dir, 'final-dom.txt'), await page.locator('body').innerText());
    } catch (error) { steps.push({ error: String(error) }); }
    await context.close();
    await page.video()?.saveAs(path.join(dir, 'interaction.webm'));
    report.push({ target, slug, url, steps });
    console.log(target, slug, steps.filter(s => s.error).length, 'failed steps');
  }
}
await browser.close();
await writeFile(path.join(root, 'report.json'), JSON.stringify(report, null, 2));
