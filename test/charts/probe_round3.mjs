import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const browser = await chromium.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
try {
  for (const reference of [false, true]) {
    for (const slug of ['liquidity-heatmap', 'returns-calendar', 'heat-calendar', 'status-bar', 'treemap', 'order-book', 'price-target-fan']) {
      const page = await browser.newPage({viewport: {width: 1280, height: 1000}, colorScheme: 'dark'});
      const url = reference ? `https://beui.dev/charts/${slug}` : `http://127.0.0.1:8109/?slug=${slug}&theme=dark&previewWidth=592&captureProbe=1`;
      await page.goto(url, {waitUntil: 'domcontentloaded'});
      if (reference) await page.getByRole('tab', {name: 'Dark theme', exact: true}).click();
      await page.waitForTimeout(2500);
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
      await page.waitForTimeout(150);
      console.log(JSON.stringify({reference, slug, nodes: await page.evaluate(() => [...document.querySelectorAll('main button, main [role="slider"], main input[type="range"], flt-semantics[role="button"], flt-semantics[role="slider"]')].map(e => ({name: e.getAttribute('aria-label') || e.textContent, role: e.getAttribute('role'), rect: e.getBoundingClientRect().toJSON()})).filter(e => e.rect.x > 280 && e.rect.y > 350 && e.rect.y < 950 && e.rect.width > 0)).then(nodes => nodes.length > 100 ? [...nodes.slice(0, 12), ...nodes.slice(-5)] : nodes)}));
      await page.close();
    }
  }
} finally { await browser.close(); }
