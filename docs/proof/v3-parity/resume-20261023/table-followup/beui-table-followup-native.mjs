import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const output=process.argv[2];await mkdir(output);const results=[];
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{
for(const side of ['source','after'])for(const reducedMotion of ['no-preference','reduce']){
 const context=await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,reducedMotion});const page=await context.newPage();const scripts=[],pending=[];
 page.on('response',r=>{if(/(?:source|main.dart)\.js$/.test(r.url()))pending.push(r.body().then(b=>scripts.push({url:r.url(),sha256:createHash('sha256').update(b).digest('hex')})));});
 await page.goto(`http://127.0.0.1:18134/${side}/?example=${side==='source'?'editable':'editable-recovery'}&theme=light`);await page.waitForTimeout(side==='source'?800:2500);
 if(side==='after'){await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(200);}
 if(side==='source')await page.addStyleTag({content:'#stage .overflow-auto {min-height:240px !important}'});
 await page.evaluate(()=>{globalThis.__tableEvents=[];for(const type of ['pointerdown','pointerup','click','keydown'])document.addEventListener(type,e=>globalThis.__tableEvents.push({type,key:e.key,pointerType:e.pointerType,isTrusted:e.isTrusted}),true);});
 const row={side,reducedMotion,composition:side==='source'?'supplemental source with explicit 240px viewport floor':'editable-recovery supplemental example',states:[],scripts};results.push(row);
 const state=async name=>{const value=await page.evaluate(()=>({inputs:[...document.querySelectorAll('input,textarea')].map(e=>({value:e.value,rect:e.getBoundingClientRect().toJSON()})),probe:globalThis.__beuiCapture??null,browserReduce:matchMedia('(prefers-reduced-motion: reduce)').matches,text:document.body.textContent}));row.states.push({name,...value});await page.screenshot({path:`${output}/${side}-${reducedMotion}-${name}.png`});};
 await state('initial');
 for(const name of ['Ava Cole','Leo Frost','Mia Vale','Kai Reyes']){
  await page.mouse.move(10,10);await page.waitForTimeout(200);
  const cell=page.locator('input,textarea').filter({visible:true});
  const target=await page.locator('input,textarea').evaluateAll((es,{name,side})=>{const e=side==='source'?es.find(x=>x.value===name):es[3];if(!e)return null;const r=e.getBoundingClientRect();const hit=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return {x:r.x+r.width/2,y:r.y+r.height/2,hit:hit===e||e.contains(hit)};},{name,side});
  assert(target?.hit,`${side} ${name} reachable`);if(side==='after'){await page.mouse.click(target.x,target.y);await page.waitForTimeout(100);assert.equal(await page.evaluate(()=>document.activeElement.value),name,'focused native field owns expected row');}await page.mouse.move(target.x,target.y);await page.waitForTimeout(180);
  await page.getByRole('button',{name:'Row 1 options',exact:true}).click();await page.getByText('Delete row',{exact:true}).click();await page.waitForTimeout(400);await state(`deleted-${name.replaceAll(' ','-')}`);
 }
 await page.getByRole('button',{name:'Insert first row',exact:true}).click();await page.waitForTimeout(300);await state('recovered');
 assert.equal(await page.getByRole('button',{name:'Insert first row',exact:true}).count(),0);
 const count=await page.locator('input,textarea').count();assert(count>=6,`${side} restored editable cells`);
 row.events=await page.evaluate(()=>globalThis.__tableEvents);assert(row.events.length>0&&row.events.every(e=>e.isTrusted));
 await Promise.all(pending);assert(scripts.length>0);assert(row.states.every(s=>s.browserReduce===(reducedMotion==='reduce')));if(side==='after')assert(row.states.every(s=>s.probe?.disableAnimations===(reducedMotion==='reduce')));
 await context.close();
}
}finally{await writeFile(`${output}/results.json`,JSON.stringify(results,null,2));await browser.close();}
