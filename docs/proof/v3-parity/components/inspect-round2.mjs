import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 1000 } });
  await page.goto('https://beui.dev/components/motion/alert', { waitUntil: 'domcontentloaded' });
  for (const theme of ['Light', 'Dark']) {
    await page.getByRole('tab', { name: `${theme} theme`, exact: true }).click();
    for (const variant of ['Info', 'Success', 'Warning', 'Error']) {
      await page.getByRole('tab', { name: variant, exact: true }).click();
      await page.waitForTimeout(400);
      console.log(JSON.stringify(await page.locator('[data-slot="alert"]').first().evaluate((el, theme) => {
        const css = getComputedStyle(el);
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        const rgba = color => {
          context.clearRect(0, 0, 1, 1);
          context.fillStyle = color;
          context.fillRect(0, 0, 1, 1);
          return [...context.getImageData(0, 0, 1, 1).data];
        };
        return { theme, variant: el.dataset.variant, color: css.color, rgba: rgba(css.color), background: css.backgroundColor, backgroundSolidRgba: rgba(css.backgroundColor.replace(/\/[^)]+\)/, '/ 1)')), height: el.getBoundingClientRect().height };
      }, theme)));
    }
  }
} finally { await browser.close(); }
