import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
const page=await browser.newPage();
await page.evaluate(()=>{globalThis.originalInsert=Node.prototype.insertBefore;});
await page.addScriptTag({path:'/tmp/beui-semantics-guard-r5.js'});
const results=await page.evaluate(()=>{
 function fixture(root=document.body){const view=document.createElement('flutter-view');const p=document.createElement('flt-semantics');view.append(p);root.append(view);const t=document.createElement('flt-semantics');t.setAttribute('flt-semantics-identifier','beui-tooltip-test');const a=document.createElement('flt-semantics');const b=document.createElement('button');a.append(b);p.append(t,a);b.focus();return {view,p,t,a,b};}
 const out={};
 const f=fixture();const wrapper=document.createElement('flt-semantics');wrapper.setAttribute('role','button');wrapper.setAttribute('aria-label','Unrelated app control');wrapper.setAttribute('flt-semantics-identifier','app-owned-control');f.p.insertBefore(wrapper,f.t);wrapper.append(f.t);const records=[];const observer=new MutationObserver(()=>{});observer.observe(f.p,{childList:true});f.p.insertBefore(f.a,wrapper);for(const r of observer.takeRecords())for(const n of r.removedNodes)records.push(n===wrapper?'app-owned-control':n===f.a?'focused-app':'other');out.nontransparentWrapper={removed:records,focusPreserved:document.activeElement===f.b,order:[...f.p.children].map(n=>n===wrapper?'app-owned-control':'focused-app')};observer.disconnect();f.view.remove();
 const one=fixture();const two=fixture();one.b.focus();one.p.insertBefore(one.a,one.t);out.multiview={focusPreserved:document.activeElement===one.b,otherOrder:two.p.firstChild===two.t};one.view.remove();two.view.remove();
 const host=document.createElement('div');document.body.append(host);const shadow=host.attachShadow({mode:'open'});const s=fixture(shadow);const focusedBefore=shadow.activeElement===s.b;const hostBefore=document.activeElement===host;s.p.insertBefore(s.a,s.t);out.shadowRoot={focusedBefore,hostBefore,activeElementIsHost:document.activeElement===host,focusPreserved:shadow.activeElement===s.b};host.remove();
 for(const [name,args] of [['undefined-reference',[undefined]],['invalid-number',[1]],['invalid-symbol',[Symbol('x')]],['extra-argument',[null,42]]]){const x=fixture();let error=null,ret;try{ret=x.p.insertBefore(x.a,...args);}catch(e){error=e.name;}out[name]={error,returnsNode:ret===x.a};x.view.remove();}
 return out;
});
await writeFile('/tmp/beui-r5-review-8luql8ea/independent-results.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results,null,2));
}finally{await browser.close();}
