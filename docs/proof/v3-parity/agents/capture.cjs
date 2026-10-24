const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/tmp/beui-agents-capture/node_modules/playwright');
const fs = require('node:fs/promises');
const path = require('node:path');

const root = __dirname;
const phase = process.argv[2] || 'before';
const catalog = ['voice-orb', 'message-bubble', 'message', 'message-scroller', 'prompt-input', 'todo-list', 'code-block', 'approval-card', 'file-diff', 'tool-result', 'streaming-response', 'image-generation', 'tool-approval', 'citations', 'agent-activity', 'loading-states', 'ai-sidebar', 'chat-app'];
const variants = process.argv.includes('--inventory')
  ? catalog.map(slug => ({ slug, theme: 'dark', width: 1440, height: 1000 }))
  : [
      { slug: 'voice-orb', theme: 'dark', width: 1440, height: 1000 },
      { slug: 'voice-orb', theme: 'light', width: 1440, height: 1000 },
      { slug: 'voice-orb', theme: 'dark', width: 390, height: 844 },
      { slug: 'voice-orb', theme: 'dark', width: 1440, height: 1000, reduced: true },
      { slug: 'prompt-input', theme: 'dark', width: 1440, height: 1000 },
      { slug: 'message', theme: 'dark', width: 1440, height: 1000 },
    ];

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  for (const spec of variants) {
    const label = `${spec.slug}-${spec.theme}-${spec.width}${spec.reduced ? '-reduced' : ''}`;
    const output = path.join(root, phase, label);
    await fs.mkdir(output, { recursive: true });
    const context = await browser.newContext({
      viewport: { width: spec.width, height: spec.height },
      deviceScaleFactor: 1,
      colorScheme: spec.theme,
      reducedMotion: spec.reduced ? 'reduce' : 'no-preference',
      recordVideo: { dir: output, size: { width: spec.width, height: spec.height } },
    });
    const page = await context.newPage();
    const failures = [];
    page.on('pageerror', error => failures.push(error.message));
    const url = phase === 'reference'
      ? `https://beui.dev/components/agents/${spec.slug}`
      : `http://localhost:8104/agents-${phase}/?slug=${spec.slug}&theme=${spec.theme}`;
    await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
    if (phase === 'reference') {
      await page.evaluate(theme => {
        document.documentElement.classList.toggle('dark', theme === 'dark');
        document.documentElement.style.colorScheme = theme;
      }, spec.theme);
    } else {
      await page.waitForSelector('flutter-view', { timeout: 30000 });
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    }
    await page.waitForTimeout(1800);
    await page.screenshot({ path: path.join(output, 'settled.png') });
    const facts = await page.evaluate(() => ({
      url: location.href,
      viewport: { width: innerWidth, height: innerHeight, dpr: devicePixelRatio },
      dark: document.documentElement.classList.contains('dark'),
      reduced: matchMedia('(prefers-reduced-motion: reduce)').matches,
      text: document.body.innerText,
      slots: [...document.querySelectorAll('[data-slot]')].map(e => ({
        slot: e.getAttribute('data-slot'), rect: e.getBoundingClientRect().toJSON(),
      })),
    }));
    if (spec.slug === 'voice-orb' && phase === 'reference') {
      const orb = page.locator('[data-slot="voice-orb"]').first();
      await orb.screenshot({ path: path.join(output, 'widget.png') });
    }
    await page.mouse.move(spec.width / 2, spec.height / 2);
    await page.waitForTimeout(600);
    await page.mouse.move(spec.width / 2 + 40, spec.height / 2 + 30);
    await page.waitForTimeout(600);
    await page.mouse.move(5, 5);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(600);
    for (let i = 0; i < 12; i++) {
      const frames = path.join(output, 'frames');
      await fs.mkdir(frames, { recursive: true });
      await page.screenshot({ path: path.join(frames, `frame_${String(i).padStart(3, '0')}.png`) });
      await page.waitForTimeout(80);
    }
    await fs.writeFile(path.join(output, 'capture.json'), JSON.stringify({ spec, facts, failures, capturedAt: new Date().toISOString() }, null, 2));
    const video = page.video();
    await context.close();
    await video.saveAs(path.join(output, 'recording.webm'));
    const original = await video.path();
    if (original !== path.join(output, 'recording.webm')) await fs.unlink(original);
    console.log(`${phase} ${label} captured`);
  }
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
