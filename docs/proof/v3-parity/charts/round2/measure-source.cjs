const puppeteer = require('/tmp/puppeteer-orb/node_modules/puppeteer-core');

const slugs = ['treemap', 'candlestick-chart', 'donut-chart', 'volume-profile', 'status-bar', 'composition-chart', 'funnel-chart', 'liquidity-heatmap', 'bump-chart', 'order-book', 'heat-calendar', 'returns-calendar', 'price-target-fan'];

(async () => {
  const browser = await puppeteer.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
  const page = await browser.newPage();
  await page.setViewport({width: Number(process.argv[2] || 1440), height: 1000, deviceScaleFactor: 1});
  try {
    for (const slug of slugs) {
      await page.goto(`https://beui.dev/charts/${slug}`, {waitUntil: 'networkidle0', timeout: 60000});
      await page.evaluate(() => document.fonts.ready);
      console.log(JSON.stringify(await page.evaluate(slug => ({
        slug, url: location.href, deploymentRevision: 'unknown',
        viewport: [innerWidth, innerHeight], dpr: devicePixelRatio,
        locale: navigator.language, timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        elements: [...document.querySelectorAll('main svg, input[type="range"], svg[role="img"], [role="slider"], [data-slot*="plot"], [aria-label*="plot"], [aria-label*="chart"], [aria-label*="profile"], [aria-label*="calendar"], [aria-label*="book"], [aria-label*="Funnel"]')].map(e => {
          const r = e.getBoundingClientRect();
          return {tag: e.tagName, label: e.getAttribute('aria-label'), slot: e.getAttribute('data-slot'), role: e.getAttribute('role'), class: e.getAttribute('class'), box: {x: r.x, y: r.y, width: r.width, height: r.height}};
        }).filter(e => e.box.width > 0 && e.box.height > 0),
      }), slug)));
    }
  } finally {
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
