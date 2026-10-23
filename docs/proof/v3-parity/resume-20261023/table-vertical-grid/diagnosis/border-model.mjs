import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{const page=await browser.newPage({viewport:{width:1280,height:1000}});await page.goto('http://127.0.0.1:18137/source/?example=data&theme=light');await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(500);
const result=await page.evaluate(()=>{
 const original=document.querySelector('table');const results=[];
 for(const variant of ['original','border0','border2','header-content-auto']) {
 const clone=original.cloneNode(true);Object.assign(clone.style,{position:'absolute',top:'0px',left:'-10000px',font:getComputedStyle(original).font});document.body.append(clone);
 if(variant==='border0'||variant==='border2') {const width=variant==='border0'?'0px':'2px';for(const e of clone.querySelectorAll('th,tbody tr'))e.style.borderBottomWidth=width;}
 if(variant==='header-content-auto')for(const e of clone.querySelectorAll('th > div'))e.style.height='auto';
 results.push({variant,rows:[...clone.rows].slice(0,3).map(r=>({y:r.getBoundingClientRect().y,height:r.getBoundingClientRect().height,content:r.cells[1]?.firstElementChild?.getBoundingClientRect().toJSON()}))});clone.remove();
 }
 return results;
});await writeFile('/tmp/beui-table-vertical-research/border-model.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await browser.close();}
