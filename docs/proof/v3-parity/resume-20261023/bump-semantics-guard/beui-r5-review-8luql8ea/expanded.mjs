import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{
 const page=await browser.newPage();
 await page.evaluate(()=>{globalThis.nativeInsert=Node.prototype.insertBefore;globalThis.nativeAppend=Element.prototype.append;});
 await page.addScriptTag({path:'/tmp/beui-semantics-guard-r5.js'});
 const results=await page.evaluate(()=>{
  const results=[];
  function fixture(){const view=document.createElement('flutter-view'),p=document.createElement('flt-semantics'),wrapper=document.createElement('flt-semantics'),marker=document.createElement('flt-semantics'),app=document.createElement('flt-semantics'),button=document.createElement('button');marker.setAttribute('flt-semantics-identifier','beui-tooltip-proof');wrapper.append(marker);app.append(button);p.append(wrapper,app);view.append(p);document.body.append(view);button.focus();return {view,p,wrapper,marker,app,button};}
  for(const [attribute,value,owned] of [['id','wrapper',true],['style','opacity: .5',true],['role','button',false],['aria-label','App label',false],['flt-semantics-identifier','app-control',false],['tabindex','0',false],['class','app',false]]){
   const f=fixture();f.wrapper.setAttribute(attribute,value);const observer=new MutationObserver(()=>{});observer.observe(f.p,{childList:true});f.p.insertBefore(f.app,f.wrapper);const removed=observer.takeRecords().flatMap(r=>[...r.removedNodes]);results.push({test:attribute,pass:(document.activeElement===f.button)===owned&&removed.includes(owned?f.wrapper:f.app)&&!removed.includes(owned?f.app:f.wrapper)});observer.disconnect();f.view.remove();
  }
  const f=fixture();f.wrapper.append(document.createTextNode(''));f.p.insertBefore(f.app,f.wrapper);results.push({test:'text child prevents wrapper ownership',pass:document.activeElement!==f.button});f.view.remove();
  for(const method of ['insertBefore','append']){const original=method==='insertBefore'?nativeInsert:nativeAppend,current=method==='insertBefore'?Node.prototype.insertBefore:Element.prototype.append;results.push({test:method+' metadata',pass:original.name===current.name&&original.length===current.length&&Object.hasOwn(original,'prototype')===Object.hasOwn(current,'prototype')});}
  globalThis.firstProxy=Node.prototype.insertBefore;
  return results;
 });
 await page.addScriptTag({path:'/tmp/beui-semantics-guard-r5.js'});
 results.push({test:'duplicate installation keeps proxy',pass:await page.evaluate(()=>firstProxy===Node.prototype.insertBefore)});
 await writeFile('/tmp/beui-r5-review-8luql8ea/expanded-results.json',JSON.stringify(results,null,2));
 console.log(JSON.stringify(results,null,2));assert(results.every(r=>r.pass));
}finally{await browser.close();}
