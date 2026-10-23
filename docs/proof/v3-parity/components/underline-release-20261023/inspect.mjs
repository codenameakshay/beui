import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const root = import.meta.dirname;
const out = join(root, process.argv[2] || 'inspection');
await mkdir(out);
const browser = await chromium.launch({headless:true, executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
  const page = await browser.newPage({viewport:{width:1280,height:1000},deviceScaleFactor:1,reducedMotion:'no-preference'});
  await page.goto('http://127.0.0.1:8112/?slug=tabs&theme=light&color=Blue&previewWidth=592&captureProbe=1');
  await page.waitForTimeout(8000);
  console.log(await page.locator('flt-semantics-placeholder').evaluateAll(es=>es.map(e=>e.outerHTML)));
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.waitForTimeout(1000);
  const state = () => page.evaluate(()=>({probe:globalThis.__beuiCapture,active:document.activeElement?.outerHTML,buttons:[...document.querySelectorAll('flt-semantics[role=button]')].map(e=>({text:e.textContent,html:e.outerHTML,rect:e.getBoundingClientRect().toJSON()}))}));
  const states = [{label:'initial',state:await state()}];
  await page.screenshot({path:join(out,'initial.png')});
  await page.keyboard.press('Shift+Tab');
  await page.waitForTimeout(300);
  states.push({label:'shift-tab',state:await state()});
  await page.keyboard.press('End');
  await page.waitForTimeout(700);
  states.push({label:'end',state:await state()});
  await page.keyboard.press('ArrowLeft');
  await page.waitForTimeout(700);
  states.push({label:'left',state:await state()});
  await page.screenshot({path:join(out,'left.png')});
  await writeFile(join(out,'states.json'),JSON.stringify(states,null,2));
  console.log(JSON.stringify(states));
} finally {await browser.close();}
