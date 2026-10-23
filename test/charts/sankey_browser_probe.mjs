import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
const [url,output]=process.argv.slice(2);
await mkdir(output,{recursive:true});
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
try{
  const page=await browser.newPage({viewport:{width:1280,height:800},reducedMotion:'reduce'});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto(url);await page.waitForTimeout(4000);
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(600);
  await page.screenshot({path:`${output}/idle.png`});
  const state=await page.evaluate(()=>({url:location.href,probe:globalThis.__beuiCapture,text:document.body.innerText,buttons:[...document.querySelectorAll('button,[role=button]')].map(e=>({text:e.getAttribute('aria-label')||e.textContent,tabIndex:e.tabIndex,rect:e.getBoundingClientRect().toJSON()})),sourcePlot:document.querySelector('[data-slot=sankey-chart-plot]')?.getBoundingClientRect().toJSON()}));
  await writeFile(`${output}/state.json`,JSON.stringify({...state,errors},null,2));
}finally{await browser.close();}
