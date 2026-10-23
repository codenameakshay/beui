import assert from 'node:assert/strict';
import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
const out=process.argv[2];assert(out,'Provide a new /tmp output directory');await mkdir(out);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const results=[];
try {
 for(const reducedMotion of ['no-preference','reduce'])for(const input of ['mouse','touch']) {
  const page=await browser.newPage({viewport:{width:1000,height:1400},hasTouch:input==='touch',reducedMotion});
  await page.goto('http://127.0.0.1:18125/?slug=funnel-chart&previewWidth=752&captureProbe=1');
  await page.waitForTimeout(4500);
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(400);
  const b=await page.getByRole('button',{name:/^Signed up: /}).boundingBox();
  const x=b.x+b.width*.2,y=b.y+b.height*.3;
  const read=()=>page.evaluate(()=>[...document.querySelectorAll('flt-semantics')].filter(e=>!e.querySelector('flt-semantics')&&/from previous stage/.test(e.textContent)).map(e=>e.textContent).join('\n'));
  if(input==='mouse')await page.mouse.move(x,y);else await page.touchscreen.tap(x,y);
  await page.waitForTimeout(500);const before=await read();assert(before.includes('65.0% from previous stage'));
  if(input==='mouse')await page.mouse.click(x,y);else await page.touchscreen.tap(x,y);
  await page.waitForTimeout(500);const after=await read();
  await page.screenshot({path:`${out}/${reducedMotion}-${input}.png`});
  results.push({input,reducedMotion,before,after,pass:after===''});await page.close();
 }
} finally {await browser.close();await writeFile(`${out}/results.json`,JSON.stringify(results,null,2));}
assert.equal(results.filter(r=>!r.pass).length,0,'Dismissal must leave no tooltip after mouse click or second touch tap');
