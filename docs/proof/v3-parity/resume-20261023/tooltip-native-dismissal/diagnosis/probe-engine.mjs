import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const variant=process.argv[2]||'baseline';
const out='/tmp/beui-dismissal-research-20261023/'+variant;
await (await import('node:fs/promises')).mkdir(out,{recursive:true});
const original=await readFile('/tmp/beui-round4-composition-funnel-quick-final-20261023/main.dart.js','utf8');
let instrumented=original;
const callbacks={bnW:'trigger-enter',bnX:'trigger-exit',bnV:'focus-change',bnT:'trigger-down',bnU:'trigger-up',bnS:'trigger-cancel',bnH:'surface-enter',bnI:'surface-exit'};
for(const [cls,name] of Object.entries(callbacks)) {
 const key=`A.${cls}.prototype={\n$1(a){`;
 if(!instrumented.includes(key))throw Error(key);
 instrumented=instrumented.replace(key,key+`globalThis.__traceDart('${name}',this.a,a);`);
}
for(const [key,name] of [['FG(a){','show'],['LN(a){','commit'],['a10(a){','finish-hide'],['aFy(a){','global-pointer']]){
 const start=instrumented.indexOf('A.Tb.prototype={');const at=instrumented.indexOf(key,start);
 instrumented=instrumented.slice(0,at+key.length)+`globalThis.__traceDart('${name}',this,a);`+instrumented.slice(at+key.length);
}
instrumented=instrumented.replace('a7i(a,b,c){var s,r=this',"a7i(a,b,c){globalThis.trace.push({t:performance.now(),type:'engine',name:'send-semantics-tap',node:c,event:a.type});var s,r=this");
await writeFile(out+'/instrumented-main.dart.js',instrumented);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const results=[];
try{for(const reducedMotion of ['no-preference','reduce'])for(const mode of ['mouse','touch']){
const page=await browser.newPage({viewport:{width:1000,height:1400},hasTouch:mode==='touch',reducedMotion});
await page.addInitScript(()=>{
 globalThis.trace=[];const ids=new WeakMap();let next=0;
 globalThis.__traceDart=(name,s,a)=>{if(!ids.has(s))ids.set(s,++next);let kind;try{kind=a?.gck?.()?.I?.()}catch{};trace.push({t:performance.now(),type:'dart',name,id:ids.get(s),arg:typeof a==='boolean'?a:undefined,kind,open:s.gim(),pointerFocus:s.y,focused:s.x,suppressed:s.z,touchWasOpen:s.as,touchStart:!!s.Q});};
 const describe=e=>e?.outerHTML?.slice(0,450);
 for(const name of ['pointerdown','pointerup','pointerover','pointerout','mousedown','mouseup','click','focus','blur','focusin','focusout','touchstart','touchend'])document.addEventListener(name,e=>trace.push({t:performance.now(),type:'dom',name,trusted:e.isTrusted,pointerType:e.pointerType,target:describe(e.target),active:describe(document.activeElement)}),true);
});
if(variant!=='baseline') await page.route('**/main.dart.js',route=>route.fulfill({contentType:'application/javascript',body:instrumented}));
await page.goto('http://127.0.0.1:18125/?slug=funnel-chart&previewWidth=752&captureProbe=1');
await page.waitForTimeout(4500);await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(400);
const box=await page.getByRole('button',{name:/^Signed up: /}).boundingBox();
const p={x:box.x+box.width*.2,y:box.y+box.height*.3};
const states=[];
const check=async name=>{await page.waitForTimeout(500);const state=await page.evaluate(p=>({text:[...document.querySelectorAll('flt-semantics')].filter(e=>!e.querySelector('flt-semantics')&&/from previous stage/.test(e.textContent)).map(e=>e.textContent).join('\n'),hit:document.elementsFromPoint(p.x,p.y).slice(0,6).map(e=>({html:e.outerHTML.slice(0,700),rect:e.getBoundingClientRect().toJSON()})),active:document.activeElement.outerHTML.slice(0,600)}),p);states.push({name,...state});await page.screenshot({path:`${out}/${reducedMotion}-${mode}-${name}.png`});};
await page.evaluate(()=>trace.push({type:'marker',name:'start',t:performance.now()}));
const intervene=async()=>{if(variant==='no-overlay-focus'||variant==='no-overlay-hit')await page.evaluate(variant=>{for(const e of document.querySelectorAll('flt-semantics'))if(e.getBoundingClientRect().width===1000&&e.hasAttribute('tabindex')&&/from previous stage/.test(e.textContent)){if(variant==='no-overlay-focus')e.removeAttribute('tabindex');else e.style.pointerEvents='none';}},variant);};
if(mode==='mouse'){await page.mouse.move(p.x,p.y);await check('hover');await intervene();await page.mouse.click(p.x,p.y);await check('click');}else{await page.touchscreen.tap(p.x,p.y);await check('tap1');await intervene();await page.touchscreen.tap(p.x,p.y);await check('tap2');}
results.push({reducedMotion,mode,box,p,states,trace:await page.evaluate(()=>trace)});await page.close();await writeFile(out+'/results.json',JSON.stringify({originalSha256:createHash('sha256').update(original).digest('hex'),instrumentedSha256:createHash('sha256').update(instrumented).digest('hex'),results},null,2));
}}finally{await browser.close()}
console.log(JSON.stringify(results.map(r=>({motion:r.reducedMotion,mode:r.mode,states:r.states.map(s=>({name:s.name,text:s.text,hit:s.hit[0]})),events:r.trace.filter(e=>e.type==='dart'&&e.name!=='global-pointer')})),null,2));
