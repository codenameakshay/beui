import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const out=process.argv[2];await mkdir(out);const rows=[];
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
for(const theme of ['light','dark']) for(const reducedMotion of ['no-preference','reduce']) for(const side of ['source','after']) {
 const context=await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,reducedMotion,recordVideo:{dir:`${out}/videos`,size:{width:1280,height:1000}}});
 const page=await context.newPage();const row={theme,reducedMotion,side,scripts:[],states:[],errors:[]};rows.push(row);const pending=[];
 page.on('pageerror',e=>row.errors.push(String(e)));
 page.on('response',r=>{if(/\/(source|main.dart)\.js$/.test(r.url()))pending.push(r.body().then(b=>row.scripts.push({url:r.url(),sha256:createHash('sha256').update(b).digest('hex')})));});
 await page.goto(`http://127.0.0.1:18139/${side}/?example=data&theme=${theme}`);await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(side==='source'?500:2500);
 if(side==='after'){await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);}
 await page.evaluate(()=>{globalThis.wheels=[];document.addEventListener('wheel',e=>globalThis.wheels.push({isTrusted:e.isTrusted,deltaY:e.deltaY}),true);});
 for(const offset of [0,26,52,104]) {
  if(offset){await page.mouse.move(700,300);await page.mouse.wheel(0,offset===104?52:26);await page.waitForTimeout(350);await page.mouse.move(1000,600);await page.waitForTimeout(150);}
  row.states.push({offset,...await page.evaluate(()=>({probe:globalThis.__beuiCapture??null,reduce:matchMedia('(prefers-reduced-motion:reduce)').matches,checks:[...document.querySelectorAll('[role=checkbox]')].map(e=>({rect:e.getBoundingClientRect().toJSON()})),sourceOffset:document.querySelector('table')?.parentElement.scrollTop??null}))});
  await page.screenshot({path:`${out}/${side}-${theme}-${reducedMotion}-${offset}.png`});
 }
 row.wheels=await page.evaluate(()=>globalThis.wheels);await Promise.all(pending);assert(row.wheels.length===3&&row.wheels.every(e=>e.isTrusted));assert(row.errors.length===0);
 assert(row.states.every(s=>s.reduce===(reducedMotion==='reduce')));
 if(side==='source')assert(row.states.every(s=>s.sourceOffset===s.offset));
 if(side==='after')assert(row.states.every(s=>s.probe.disableAnimations===(reducedMotion==='reduce')));
 const video=page.video();await context.close();row.video=await video.path();
}
} finally {await writeFile(`${out}/results.json`,JSON.stringify(rows,null,2));await browser.close();}
