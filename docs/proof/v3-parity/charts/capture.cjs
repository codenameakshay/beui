const fs = require('node:fs');
const path = require('node:path');
const puppeteer = require('/tmp/puppeteer-orb/node_modules/puppeteer-core');

const root = __dirname;
const slugs = ['treemap', 'candlestick-chart', 'donut-chart', 'volume-profile', 'status-bar', 'composition-chart', 'funnel-chart', 'liquidity-heatmap', 'bump-chart', 'order-book', 'heat-calendar', 'returns-calendar', 'price-target-fan'];
const phase = process.argv[2] || 'before';
const selected = process.argv[3] ? [process.argv[3]] : slugs;
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  const browser = await puppeteer.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true, args: ['--no-sandbox', '--autoplay-policy=no-user-gesture-required']});
  try {
    const page = await browser.newPage();
    await page.setViewport({width: 1440, height: 1000, deviceScaleFactor: 1});
    for (const slug of selected) {
      const dir = path.join(root, phase, slug);
      fs.mkdirSync(dir, {recursive: true});
      const reference = phase === 'reference';
      const url = reference ? `https://beui.dev/charts/${slug}` : `http://127.0.0.1:8101/?slug=${slug}&theme=dark`;
      await page.goto(url, {waitUntil: 'networkidle0', timeout: 60000});
      await pause(1800);
      if (reference) await page.evaluate(() => document.documentElement.classList.add('dark'));
      await page.screenshot({path: path.join(dir, 'idle.png')});
      fs.writeFileSync(path.join(dir, 'page.json'), JSON.stringify(await page.evaluate(() => ({url: location.href, viewport: [innerWidth, innerHeight], text: document.body.innerText, elements: [...document.querySelectorAll('button,svg,canvas,[role="slider"],[role="img"]')].map(e => ({tag:e.tagName, role:e.getAttribute('role'), label:e.getAttribute('aria-label'), text:e.textContent?.slice(0,150), box:(r=>({x:r.x,y:r.y,width:r.width,height:r.height}))(e.getBoundingClientRect())})).filter(e=>e.box.width>0&&e.box.height>0)})), null, 2));
      const recorder = await page.screencast({path: path.join(dir, 'interaction.webm'), fps: 30});
      await pause(400);
      for (const [x,y] of [[540,460],[700,460],[850,460],[1000,500],[900,550]]) {
        await page.mouse.move(x,y,{steps:8});
        await pause(500);
      }
      await page.screenshot({path: path.join(dir, 'hover.png')});
      await page.mouse.click(700,460);
      await pause(350);
      await page.keyboard.press('Tab');
      await page.keyboard.press('ArrowRight');
      await page.keyboard.press('Home');
      await pause(350);
      await page.keyboard.press('Escape');
      await page.mouse.move(400,180,{steps:8});
      await pause(600);
      await recorder.stop();
      console.log(`${phase}/${slug}`);
    }
  } finally {
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode=1;});
