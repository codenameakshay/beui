import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root='/tmp/heat-calendar-continuation/custom-native';await fs.mkdir(root);
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const reports=[];
try {for(const layout of ['none','middle']) for(const direction of ['forward','reverse']) {
 const context=await browser.newContext({viewport:{width:1000,height:800},reducedMotion:'reduce'});const page=await context.newPage();const errors=[],scripts=[],pending=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('response',r=>{if(/\.js(?:\?|$)/.test(r.url()))pending.push(r.body().then(b=>scripts.push({url:r.url(),sha256:createHash('sha256').update(b).digest('hex')})))});
 await page.addInitScript(()=>{window.inputs=[];for(const type of ['keydown','keyup','pointerdown','click','focusin'])document.addEventListener(type,e=>inputs.push({type,key:e.key,trusted:e.isTrusted,text:e.target.textContent,x:e.clientX,y:e.clientY}),true)});
 await page.goto('http://127.0.0.1:18153/custom/example/build/web/?layout='+layout);await page.waitForFunction(()=>globalThis.__fixture?.snapshot);await page.locator('flt-semantics-placeholder').evaluateAll(ns=>ns.forEach(n=>n.click()));await page.waitForTimeout(800);
 const states=[];const snap=async name=>{await page.waitForTimeout(400);const s=await page.evaluate(()=>({focus:{tag:document.activeElement.tagName,text:document.activeElement.textContent},inputs}));s.name=name;s.aria=await page.locator('body').ariaSnapshot();await page.screenshot({path:`${root}/${layout}-${direction}-${name}.png`});states.push(s);return s;};
 const box=await page.getByRole('button',{name:/commits on Fri, Oct 23/}).boundingBox();await page.mouse.click(box.x+box.width/2,box.y+box.height/2);await page.mouse.move(10,10);await page.keyboard.press('Escape');await page.keyboard.press('d');const removed=await snap('removed');await page.keyboard.press(direction==='forward'?'Tab':'Shift+Tab');const next=await snap('next');
 const expected=direction==='reverse'?'0 commits on Mon, Oct 19':layout==='none'?'after':'middle';
 await Promise.all(pending);reports.push({layout,direction,states,scripts,errors,checks:{removed:removed.focus.tag==='FLUTTER-VIEW',next:next.focus.text===expected,trusted:next.inputs.filter(i=>!i.trusted).every(i=>i.type==='click'&&i.x===0&&i.y===0),noErrors:!errors.length}});await context.close();
}}finally{await browser.close();await fs.writeFile(root+'/results.json',JSON.stringify(reports,null,2));}
console.log(reports.map(({layout,direction,checks})=>({layout,direction,checks})));
