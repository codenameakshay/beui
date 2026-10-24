import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const browser = await chromium.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
try {
  const page = await browser.newPage({viewport: {width: 1280, height: 1000}, hasTouch: true});
  page.on('console', message => {if (message.text().includes('FAN')) console.log(message.text());});
  await page.goto('http://127.0.0.1:8109/?slug=price-target-fan&theme=dark&previewWidth=592&captureProbe=1');
  await page.waitForTimeout(3000);
  await page.evaluate(() => {
    for (const type of ['pointerdown', 'pointerup', 'pointerenter', 'pointerleave', 'mousedown', 'mouseup', 'click', 'focusin']) {
      document.addEventListener(type, event => console.log('FAN DOM', type, event.pointerType, event.isTrusted, event.target.tagName), true);
    }
  });
  for (let i = 0; i < 3; i++) {
    console.log(`FAN TAP ${i + 1}`);
    await page.touchscreen.tap(952.5, 391.2857);
    await page.waitForTimeout(800);
  }
} finally {await browser.close();}
