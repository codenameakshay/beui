import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});const page=await browser.newPage({viewport:{width:1280,height:1000}});
try{await page.goto('http://127.0.0.1:18134/source/?example=data&theme=light');await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(400);
const result=await page.evaluate(()=>{
 const table=document.querySelector('table');const rows=[...table.rows].filter(r=>r.cells.length===7);const measured=[];
 for(let i=0;i<7;i++){
  const entry={index:i,rendered:rows[0].cells[i].getBoundingClientRect().width,rows:rows.length};
  for(const policy of ['min-content','max-content']){
   const clone=document.createElement('table');clone.className=table.className;Object.assign(clone.style,{position:'absolute',left:'-10000px',top:'0',width:policy,tableLayout:'auto',font:getComputedStyle(table).font,letterSpacing:getComputedStyle(table).letterSpacing});
   for(const row of rows){const r=row.cloneNode(false);const c=row.cells[i].cloneNode(true);c.removeAttribute('style');r.append(c);clone.append(r);}
   document.body.append(clone);entry[policy]=clone.getBoundingClientRect().width;clone.remove();
  }measured.push(entry);
 }
 return {url:location.href,table:table.getBoundingClientRect().toJSON(),measured,browser:navigator.userAgent};
});await writeFile('/tmp/beui-table-content-metrics-inherited.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await browser.close();}
