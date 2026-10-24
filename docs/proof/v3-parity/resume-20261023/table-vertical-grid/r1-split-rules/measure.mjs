import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const out='/tmp/beui-table-vertical-after-r1';
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const result=[];
try {for (const side of ['source','after']) for(const reducedMotion of ['no-preference','reduce']) {
 const context=await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,reducedMotion}); const page=await context.newPage(); const scripts=[],pending=[];
 page.on('response',r=>{if(/\/(source|main.dart)\.js$/.test(r.url()))pending.push(r.body().then(b=>scripts.push({url:r.url(),sha256:createHash('sha256').update(b).digest('hex')})));});
 await page.goto(`http://127.0.0.1:18138/${side}/?example=data&theme=light`); await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(side==='source'?500:2500);
 if(side==='after'){await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);}
 const data=await page.evaluate(()=>{
 const rect=e=>e.getBoundingClientRect().toJSON();const props=['display','height','lineHeight','fontFamily','fontSize','fontWeight','letterSpacing','verticalAlign','boxSizing','borderCollapse','borderTopWidth','borderBottomWidth','paddingTop','paddingBottom','borderBottomColor'];
 const describe=e=>({tag:e.tagName,text:e.textContent,rect:rect(e),css:Object.fromEntries(props.map(k=>[k,getComputedStyle(e)[k]]))});
 const table=document.querySelector('table');
 if(!table)return {probe:globalThis.__beuiCapture,semantics:[...document.querySelectorAll('flt-semantics')].map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:e.childElementCount?null:e.textContent,rect:rect(e)}))};
 const rows=[...table.rows].slice(0,10).map(r=>({...describe(r),cells:[...r.cells].map(c=>({...describe(c),children:[...c.children].map(describe),texts:[]}))}));
 // A zero-size inline baseline marker, removed immediately after reading, probes the inline formatting baseline.
 for(let ri=0;ri<rows.length;ri++) for(let ci=0;ci<rows[ri].cells.length;ci++) {
 const cell=table.rows[ri].cells[ci];const walker=document.createTreeWalker(cell,NodeFilter.SHOW_TEXT);let t;
 while(t=walker.nextNode()){if(!t.textContent.trim())continue;const range=document.createRange();range.selectNodeContents(t);const before=rect(cell),textRect=range.getBoundingClientRect().toJSON();const marker=document.createElement('span');marker.style.cssText='display:inline-block;width:0;height:0;padding:0;margin:0;border:0;vertical-align:baseline';t.parentNode.insertBefore(marker,t.nextSibling);const baseline=rect(marker).y;const stable=JSON.stringify(before)===JSON.stringify(rect(cell));marker.remove();rows[ri].cells[ci].texts.push({text:t.textContent,rect:textRect,baseline,cellStable:stable,parent:describe(t.parentElement)});}
 }
 return {table:describe(table),viewport:describe(table.parentElement),rows};
 });
 await page.screenshot({path:`${out}/${side}-${reducedMotion}.png`});await Promise.all(pending);result.push({side,reducedMotion,scripts,data});await context.close();
}}finally{await writeFile(`${out}/measurements.json`,JSON.stringify(result,null,2));await browser.close();}
