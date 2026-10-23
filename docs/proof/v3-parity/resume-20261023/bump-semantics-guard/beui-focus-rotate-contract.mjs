import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const page=await browser.newPage();
const result=await page.evaluate(()=>{
 const native=Node.prototype.insertBefore;
 function reorder(parent,node,reference){
  const active=document.activeElement;
  if(node.parentNode!==parent || !parent.isConnected || !node.contains(active))return native.call(parent,node,reference);
  const children=[...parent.childNodes],from=children.indexOf(node),to=reference===null?children.length:children.indexOf(reference);
  if(to<0)return native.call(parent,node,reference);
  if(to<from){const after=node.nextSibling;for(const sibling of children.slice(to,from))native.call(parent,sibling,after);}
  else if(to>from){for(const sibling of children.slice(from+1,to))native.call(parent,sibling,node);}
  return node;
 }
 let cases=0;const fails=[];let baselineBlurred=false;
 for(let n=1;n<=8;n++)for(let from=0;from<n;from++)for(let to=0;to<=n;to++){
  const parent=document.createElement('flt-semantics');document.body.append(parent);
  const children=Array.from({length:n},(_,i)=>{const node=document.createElement('flt-semantics');node.id='n'+i;parent.append(node);return node;});
  const button=document.createElement('button');children[from].append(button);button.focus();let blurs=0;button.addEventListener('blur',()=>blurs++);
  const expected=children.map(x=>x.id); if(to!==from){const [id]=expected.splice(from,1);expected.splice(to>from?to-1:to,0,id);}
  reorder(parent,children[from],children[to]??null);
  if(JSON.stringify([...parent.children].map(x=>x.id))!==JSON.stringify(expected)||document.activeElement!==button||blurs)fails.push({n,from,to});
  cases++;parent.remove();
 }
 const p=document.createElement('flt-semantics'),a=document.createElement('flt-semantics'),b=document.createElement('flt-semantics'),focused=document.createElement('button'),newer=document.createElement('button');
 document.body.append(p,newer);p.append(a,b);a.append(focused);focused.focus();native.call(p,a,null);baselineBlurred=document.activeElement!==focused;
 focused.focus();newer.focus();reorder(p,a,b);const explicitNewerPreserved=document.activeElement===newer;
 focused.focus();a.remove();reorder(p,a,b);const detachedNotRefocused=document.activeElement!==focused;
 return {cases,fails,baselineBlurred,explicitNewerPreserved,detachedNotRefocused,userAgent:navigator.userAgent};
});
await writeFile('/tmp/beui-focus-rotate-contract-results.json',JSON.stringify(result,null,2),{flag:'wx'});
console.log(result);await browser.close();
if(result.fails.length||!result.baselineBlurred||!result.explicitNewerPreserved||!result.detachedNotRefocused)process.exitCode=1;
