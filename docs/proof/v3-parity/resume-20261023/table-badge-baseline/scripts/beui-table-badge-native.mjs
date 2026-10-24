import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const output=process.argv[2]; await mkdir(output); const results=[];
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
for(const side of ['source','after']) for(const reducedMotion of ['no-preference','reduce']) {
 const context=await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,reducedMotion,recordVideo:{dir:`${output}/videos`,size:{width:1280,height:1000}}});
 const page=await context.newPage();const scripts=[],pending=[],errors=[];page.on('pageerror',e=>errors.push(String(e)));
 page.on('response',r=>{if(/\/(source|main.dart)\.js$/.test(r.url()))pending.push(r.body().then(b=>scripts.push({url:r.url(),sha256:createHash('sha256').update(b).digest('hex')})));});
 await page.goto(`http://127.0.0.1:18142/${side}/?example=data&theme=light`); await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(side==='source'?500:2500);
 if(side!=='source'){await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);}
 const row={side,reducedMotion,scripts,errors,states:[]};results.push(row);
 await page.evaluate(()=>{globalThis.events=[];for(const type of ['pointerdown','pointerup','pointermove'])document.addEventListener(type,e=>globalThis.events.push({type,isTrusted:e.isTrusted,pointerType:e.pointerType,x:e.clientX,y:e.clientY}),true);});
 const state=async phase=>{const value=await page.evaluate(()=>({
  probe:globalThis.__beuiCapture??null, reduce:matchMedia('(prefers-reduced-motion:reduce)').matches,
  handles:[...document.querySelectorAll('[aria-label]')].filter(e=>/^Resize .* column$/.test(e.getAttribute('aria-label'))).map(e=>({label:e.getAttribute('aria-label'),rect:e.getBoundingClientRect().toJSON()})),
  cols:[...document.querySelectorAll('col')].map(e=>({width:e.getBoundingClientRect().width,style:e.getAttribute('style')})),
  text:document.body.innerText,semantics:[...document.querySelectorAll('flt-semantics')].map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:e.childElementCount?null:e.textContent,rect:e.getBoundingClientRect().toJSON()})),
  checkbox:[...document.querySelectorAll('[role=checkbox],input[type=checkbox]')].map(e=>({rect:e.getBoundingClientRect().toJSON(),checked:e.getAttribute('aria-checked')})),
 }));value.handles=[]; for(const key of ['name','email','role','status','mrr']) { const label=`Resize ${key} column`; value.handles.push({label,rect:await page.getByRole('button',{name:label,exact:true}).boundingBox()}); } assert(value.handles.every(h=>h.rect));row.states.push({phase,recordedAt:new Date().toISOString(),...value});await page.screenshot({path:`${output}/${side}-${reducedMotion}-${phase}.png`});};
 await state('rest'); const h=page.getByRole('button',{name:'Resize name column',exact:true}); const rect=await h.boundingBox();assert(rect); const x=rect.x+rect.width/2,y=rect.y+rect.height/2;
 await page.mouse.move(x,y);await page.mouse.down();await page.waitForTimeout(150);await state('freeze');
 await page.mouse.move(x+50,y);await page.mouse.up();await page.waitForTimeout(200);await state('drag50');
 row.events=await page.evaluate(()=>globalThis.events);await Promise.all(pending);
 assert(scripts.length);assert(errors.length===0,errors.join('\n'));assert(row.events.every(e=>e.isTrusted));assert(row.states.every(s=>s.reduce===(reducedMotion==='reduce')));
 if(side!=='source')assert(row.states.every(s=>s.probe?.disableAnimations===(reducedMotion==='reduce')));
 const video=page.video(); await context.close(); row.video=await video.path();
}
} finally {await writeFile(`${output}/results.json`,JSON.stringify(results,null,2));await browser.close();}
