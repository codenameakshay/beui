const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/tmp/beui-agents-capture/node_modules/playwright');
const path = require('node:path');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 80 }, deviceScaleFactor: 1 });
  await page.setContent(`<style>body{margin:0;background:#151515;color:#eee;font:18px Arial}main{display:flex;padding:14px 20px 8px;gap:50px}section{width:50%}p{margin:0 20px;font-size:15px;color:#bbb}</style><main><section>BEFORE 5ec78ac. Two orbs. Fixed 288px main orb.</section><section>AFTER. One orb. 256px below 640px. Stationary error fallback.</section></main><p>Actual browser recordings. Clocks are not synchronized. Exact motion parity remains unproven.</p>`);
  await page.screenshot({ path: path.join(__dirname, 'before-after-caption.png') });
  await page.setContent(`<style>body{margin:0;background:#151515;color:#eee;font:20px Arial}h1{margin:12px 20px 8px;font-size:21px}p{margin:0 20px;font-size:16px;color:#bbb}</style><h1>NEW WIDGET. Voice Orb.</h1><p>Source pigments and simulated activity. Responsive size and stationary error fallback repaired. Exact motion parity remains unproven.</p>`);
  await page.screenshot({ path: path.join(__dirname, 'new-widget-caption.png') });
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
