import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const browser = await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
try {
  const page = await browser.newPage({viewport:{width:1280,height:1000}});
  await page.goto('http://127.0.0.1:18114/?chart=candle&theme=dark');
  await page.waitForTimeout(2000);
  const plot = await page.getByRole('slider').boundingBox();
  const sample = () => page.locator('svg > g').last().evaluate(e=>getComputedStyle(e).opacity);
  await page.mouse.move(plot.x+5,plot.y+80);
  await page.waitForTimeout(650);
  console.log('inflight',await sample());
  await page.mouse.move(plot.x+(plot.width-64)*47.5/48,plot.y+80);
  for(const ms of [50,100,300,200,300]) {
    await page.waitForTimeout(ms);
    console.log(ms,await sample());
  }
} finally {await browser.close();}
