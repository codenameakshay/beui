import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { writeFile } from 'node:fs/promises';
const browser = await chromium.launch({ headless:true, executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
try {
  const page = await browser.newPage({viewport:{width:1280,height:1000}});
  await page.goto('http://127.0.0.1:8110/?slug=color-picker&theme=light&color=Blue&previewWidth=592&captureProbe=1');
  await page.waitForTimeout(3000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.getByRole('button',{name:'#3478f6',exact:true}).click();
  await page.waitForTimeout(2500);
  const state = await page.evaluate(() => [...document.querySelectorAll('flt-semantics,flt-semantics input')].map(el=>({html:el.outerHTML.slice(0,1800),rect:el.getBoundingClientRect().toJSON()})));
  await writeFile(new URL('picker-dom.json',import.meta.url),JSON.stringify(state,null,2));
  await page.screenshot({path:new URL('picker-settled.png',import.meta.url).pathname});
  console.log(JSON.stringify(state.filter(x=>x.html.includes('Saturation')||x.html.includes('Hue')||x.html.includes('Opacity')).slice(-12)));
} finally {await browser.close();}
