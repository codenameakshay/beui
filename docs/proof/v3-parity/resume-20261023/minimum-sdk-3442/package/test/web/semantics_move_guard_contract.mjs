const {chromium,firefox,webkit}=await import(process.env.PLAYWRIGHT_MODULE??'playwright-core');
import {mkdir,writeFile,readFile,access} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const [script,output]=process.argv.slice(2);await mkdir(output);
const results=[];
const required=new Set((process.env.REQUIRED_BROWSERS??'chromium').split(','));
assert([...required].every(x=>['chromium','firefox','webkit'].includes(x)),'unknown required browser');
for(const [name,type,path] of [['chromium',chromium,process.env.CHROMIUM_EXECUTABLE??chromium.executablePath()],['firefox',firefox,process.env.FIREFOX_EXECUTABLE??firefox.executablePath()],['webkit',webkit,process.env.WEBKIT_EXECUTABLE??webkit.executablePath()]]){
 try{await access(path);}catch{results.push({name,unavailable:path});continue;}
 let browser;try{browser=await type.launch({headless:true,executablePath:path,timeout:30000});}catch(e){results.push({name,unavailable:String(e)});continue;}
 try{
 const page=await browser.newPage();
 await page.evaluate(()=>{globalThis.originalInsert=Node.prototype.insertBefore;globalThis.originalAppend=Element.prototype.append;});
 await page.addScriptTag({path:script});
 const result=await page.evaluate(()=>{
  const errors=[];let cases=0;
  function check(ok,label){if(!ok)errors.push(label);}
  function fixture(n=3,from=1,{owned=true,flutter=true}={}){
   const view=document.createElement(flutter?'flutter-view':'div');const parent=document.createElement('flt-semantics');view.append(parent);document.body.append(view);
   const nodes=Array.from({length:n},(_,i)=>{const e=document.createElement('flt-semantics');e.id='item'+i;if(i!==from&&owned)e.setAttribute('flt-semantics-identifier','beui-tooltip-test'+i);parent.append(e);return e;});
   const button=document.createElement('button');nodes[from].append(button);button.focus();return {view,parent,nodes,button};
  }
  const baseline=fixture();originalInsert.call(baseline.parent,baseline.nodes[1],baseline.nodes[0]);check(document.activeElement!==baseline.button,'baseline must blur');baseline.view.remove();
  for(let n=1;n<=8;n++)for(let from=0;from<n;from++)for(let to=0;to<=n;to++){
   const f=fixture(n,from);const expected=f.nodes.map(x=>x.id);if(to!==from){const [id]=expected.splice(from,1);expected.splice(to>from?to-1:to,0,id);}
   let blurs=0;f.button.addEventListener('blur',()=>blurs++);
   const returned=f.parent.insertBefore(f.nodes[from],f.nodes[to]??null);
   check(returned===f.nodes[from],`return ${n}/${from}/${to}`);
   check(JSON.stringify([...f.parent.children].map(x=>x.id))===JSON.stringify(expected),`order ${n}/${from}/${to}`);
   if(to!==from&&to!==from+1){check(document.activeElement===f.button&&blurs===0,`focus ${n}/${from}/${to}`);}else{const observed=document.activeElement===f.button;const native=fixture(n,from);originalInsert.call(native.parent,native.nodes[from],native.nodes[to]??null);check(observed===(document.activeElement===native.button),`native no-op ${n}/${from}/${to}`);native.view.remove();}cases++;f.view.remove();
  }
  for(const mode of ['unowned','unrelated','cross-parent','detached','newer-focus','invalid-reference','invalid-node','missing-argument','append','append-multiple','append-text','wrapper','mixed-wrapper','application-wrapper']){
   const f=fixture(3,1,{owned:mode!=='unowned',flutter:mode!=='unrelated'});
   if(mode==='unowned'||mode==='unrelated'){f.parent.insertBefore(f.nodes[1],f.nodes[0]);check(document.activeElement!==f.button,mode);}
   if(mode==='cross-parent'){const other=document.createElement('flt-semantics');f.view.append(other);other.insertBefore(f.nodes[1],null);check(document.activeElement!==f.button&&f.nodes[1].parentNode===other,mode);}
   if(mode==='detached'){f.nodes[1].remove();f.parent.insertBefore(f.nodes[1],f.nodes[0]);check(document.activeElement!==f.button,mode);}
   if(mode==='newer-focus'){const newer=document.createElement('button');f.view.append(newer);newer.focus();f.parent.insertBefore(f.nodes[1],f.nodes[0]);check(document.activeElement===newer,mode);}
   if(mode==='invalid-reference'){let e;try{f.parent.insertBefore(f.nodes[1],document.createElement('div'));}catch(x){e=x;}check(e?.name==='NotFoundError'&&document.activeElement===f.button,mode);}
   if(mode==='invalid-node'){let e;try{f.parent.insertBefore({},null);}catch(x){e=x;}check(e instanceof TypeError,mode);}
   if(mode==='missing-argument'){let e;try{f.parent.insertBefore(f.nodes[1]);}catch(x){e=x;}check(e instanceof TypeError,mode);}
   if(mode==='append'){const returned=f.parent.append(f.nodes[1]);check(returned===undefined&&f.parent.lastChild===f.nodes[1]&&document.activeElement===f.button,mode);}
   if(mode==='append-multiple'){const extra=document.createElement('div');f.parent.append(f.nodes[1],extra);check(f.parent.lastChild===extra&&document.activeElement!==f.button,mode);}
   if(mode==='append-text'){f.parent.append('a','b','c');check(f.parent.textContent==='abc',mode);}
   if(mode==='wrapper'||mode==='mixed-wrapper'||mode==='application-wrapper'){const marker=f.nodes[0].getAttribute('flt-semantics-identifier');f.nodes[0].removeAttribute('flt-semantics-identifier');const child=document.createElement('flt-semantics');child.setAttribute('flt-semantics-identifier',marker);f.nodes[0].append(child);if(mode==='application-wrapper'){f.nodes[0].setAttribute('role','button');f.nodes[0].setAttribute('aria-label','App control');f.nodes[0].setAttribute('flt-semantics-identifier','app-control');}if(mode==='mixed-wrapper')f.nodes[0].append(document.createElement('button'));f.parent.insertBefore(f.nodes[1],f.nodes[0]);check((document.activeElement===f.button)===(mode==='wrapper'),mode);}
   f.view.remove();
  }
  const host=document.createElement('div');document.body.append(host);const shadow=host.attachShadow({mode:'open'});const sh=fixture();shadow.append(sh.view);sh.button.focus();sh.parent.insertBefore(sh.nodes[1],sh.nodes[0]);check(shadow.activeElement===sh.button,'shadow focus');host.remove();
  for(const method of ['insertBefore','append']){let error;try{Reflect.apply(method==='insertBefore'?Node.prototype.insertBefore:Element.prototype.append,{},[document.createElement('div'),null]);}catch(e){error=e;}check(error instanceof TypeError,`wrong receiver ${method}`);}
  return {cases,errors,userAgent:navigator.userAgent};
 });
 results.push({name,...result});await page.close();
 }finally{await browser.close();}
}
await writeFile(`${output}/results.json`,JSON.stringify({scriptSha256:createHash('sha256').update(await readFile(script)).digest('hex'),results},null,2));
assert(results.some(r=>r.cases>0),'no browser executed');
for(const name of required)assert(results.some(r=>r.name===name&&r.cases>0),`required browser unavailable: ${name}`);
for(const r of results)if(r.errors)assert.deepEqual(r.errors,[],r.name);
console.log(JSON.stringify(results));
