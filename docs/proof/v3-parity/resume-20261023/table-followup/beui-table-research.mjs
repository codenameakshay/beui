import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const page=await browser.newPage({viewport:{width:1280,height:1000},deviceScaleFactor:1,reducedMotion:'no-preference'});
const out=[];const save=async(name)=>{const x=await page.evaluate(()=>{const r=e=>e.getBoundingClientRect().toJSON();const t=document.querySelector('table');const s=t.parentElement;return {table:r(t),style:t.getAttribute('style'),class:t.className,scroll:{rect:r(s),top:s.scrollTop,height:s.scrollHeight,client:s.clientHeight},cols:[...document.querySelectorAll('col')].map(e=>({style:e.getAttribute('style'),rect:r(e)})),headers:[...document.querySelectorAll('th')].map(e=>({text:e.innerText,rect:r(e)})),inputs:[...document.querySelectorAll('input')].map(e=>({value:e.value,rect:r(e),hit:document.elementFromPoint(r(e).x+20,r(e).y+r(e).height/2)?.outerHTML.slice(0,160)})),buttons:[...document.querySelectorAll('button')].map(e=>({text:e.textContent,label:e.getAttribute('aria-label'),rect:r(e)}))}});out.push({name,...x});await page.screenshot({path:`/tmp/beui-table-research-${name}.png`});console.log(name,JSON.stringify(x));return x;};
await page.goto('http://127.0.0.1:18134/source/?example=data&theme=light');await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(400);
await page.getByRole('button',{name:'Name',exact:true}).click();await page.keyboard.press('Enter');await page.waitForTimeout(220);await page.getByRole('checkbox').nth(1).click();await page.getByRole('checkbox').nth(0).click();
let x=await save('data-rest');let h=page.getByRole('button',{name:'Resize name column',exact:true});let b=await h.boundingBox();await page.mouse.move(b.x+3,67);await page.mouse.down();await page.waitForTimeout(80);await save('data-down');await page.mouse.move(b.x+53,67);await page.mouse.up();await page.waitForTimeout(200);await save('data-move');
await page.goto('http://127.0.0.1:18134/source/?example=editable&theme=light');await page.waitForTimeout(400);
for(let i=0;i<4;i++){
 x=await save(`editable-${4-i}-rows`);let cell=x.inputs[3];await page.mouse.move(10,10);await page.waitForTimeout(180);await page.mouse.move(cell.rect.x+cell.rect.width/2,cell.rect.y+cell.rect.height/2);await page.waitForTimeout(100);
 let trigger=page.getByRole('button',{name:'Row 1 options',exact:true});console.log('trigger',await trigger.count());
 if(!await trigger.count()) break;
 b=await trigger.boundingBox();await page.mouse.click(b.x+b.width/2,b.y+b.height/2);await page.waitForTimeout(200);
 let del=page.getByText('Delete row',{exact:true});console.log('delete',await del.count());if(!await del.count()){await save('editable-missing-menu');break;}await del.click();await page.waitForTimeout(350);
}
await save('editable-end');
await page.mouse.move(600,200);await page.mouse.wheel(0,300);await page.waitForTimeout(250);await save('editable-wheel');
await page.addStyleTag({content:'table { } table:has(input) { } #stage .overflow-auto {min-height:240px !important}'});
await page.waitForTimeout(250);x=await save('editable-height240');let cell=x.inputs[3];await page.mouse.move(10,10);await page.waitForTimeout(180);await page.mouse.move(cell.rect.x+20,cell.rect.y+14);await page.waitForTimeout(120);await page.getByRole('button',{name:'Row 1 options',exact:true}).click();await page.getByText('Delete row',{exact:true}).click();await page.waitForTimeout(250);await save('editable-empty240');await page.getByRole('button',{name:'Insert first row',exact:true}).click();await page.waitForTimeout(250);await save('editable-recovered240');await writeFile('/tmp/beui-table-research.json',JSON.stringify(out,null,2));await browser.close();
