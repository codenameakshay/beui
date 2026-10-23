import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { writeFile } from 'node:fs/promises';
const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
  const page=await browser.newPage({viewport:{width:1280,height:1000}});
  await page.goto('http://127.0.0.1:8110/?slug=combobox&theme=light&color=Blue&previewWidth=592&captureProbe=1',{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(3000);
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
  const box = await page.locator('[aria-label="Search workspaces"]').last().boundingBox();
  await page.mouse.click(box.x+box.width/2,box.y+box.height/2);
  await page.waitForTimeout(1200);
  const read=()=>page.evaluate(()=>({active:document.activeElement?.outerHTML, inputs:[...document.querySelectorAll('input,textarea')].map(e=>({html:e.outerHTML,value:e.value,readOnly:e.readOnly,rect:e.getBoundingClientRect().toJSON()}))}));
  const before=await read();
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.insertText('Product');
  await page.waitForTimeout(1000);
  const after=await read();
  await writeFile(new URL('combobox-dom.json',import.meta.url),JSON.stringify({before,after},null,2));
  await page.screenshot({path:new URL('combobox-input-observed.png',import.meta.url).pathname});
  console.log(JSON.stringify({before,after}));
} finally {await browser.close();}
