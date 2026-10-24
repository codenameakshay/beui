import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const output=`${import.meta.dirname}/${process.argv[2]}`;await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const results=[];
try {
 for(const side of ['source','after'])for(const motion of ['no-preference','reduce'])for(const scenario of ['narrow','offscreen','restore']){
  const r={side,motion,scenario,states:[],scripts:[]};results.push(r);
  const page=await browser.newPage({viewport:{width:800,height:600},reducedMotion:motion});const reads=[];
  page.on('response',s=>{if(/\.js$/.test(s.url()))reads.push(s.body().then(b=>r.scripts.push({url:s.url(),sha256:createHash('sha256').update(b).digest('hex')})));});
  try {
   await page.goto(`http://127.0.0.1:18123/${side}/?scenario=${scenario}`);await page.waitForTimeout(1800);
   if(side==='after')await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await page.waitForTimeout(200);
   const state=async name=>{await page.waitForTimeout(300);const value=await page.evaluate(()=>{const a=document.activeElement;return {active:a?.getAttribute('aria-label')||a?.textContent,rect:a?.getBoundingClientRect().toJSON(),tabStops:[...document.querySelectorAll('button,[role=button]')].filter(e=>e.tabIndex===0&&/^[ABC]\./.test(e.getAttribute('aria-label')||e.textContent)).map(e=>e.getAttribute('aria-label')||e.textContent),reduced:matchMedia('(prefers-reduced-motion: reduce)').matches}});r.states.push({name,...value});await page.screenshot({path:`${output}/${side}-${motion}-${scenario}-${name}.png`});assert.equal(value.reduced,motion==='reduce');return value;};
   await page.getByRole('button',{name:'Before',exact:true}).click();await page.keyboard.press('Tab');let s=await state('first');assert.match(s.active,/^A\./);
   if(scenario==='narrow'){await page.keyboard.press('End');s=await state('end');assert.match(s.active,/^C\./);assert(s.rect.x+s.rect.width/2>=242&&s.rect.x+s.rect.width/2<=558);await page.keyboard.press('Home');s=await state('home');assert.match(s.active,/^A\./);assert(s.rect.x+s.rect.width/2>=242&&s.rect.x+s.rect.width/2<=558);}
   if(scenario==='offscreen'){assert(s.rect.y>=0&&s.rect.y+s.rect.height/2<=600);}
   if(scenario==='restore'){await page.keyboard.press('ArrowDown');s=await state('second');assert.match(s.active,/^B\./);await page.getByRole('button',{name:'Outside',exact:true}).click();await page.keyboard.press('r');s=await state('removed');assert(s.tabStops.every(x=>/^A\./.test(x))&&s.tabStops.length===1);await page.keyboard.press('i');s=await state('restored');assert(s.tabStops.every(x=>/^A\./.test(x))&&s.tabStops.length===1);}
   r.pass=true;
  }catch(e){r.error=String(e);await page.screenshot({path:`${output}/${side}-${motion}-${scenario}-failure.png`});}
  await Promise.all(reads);await writeFile(`${output}/results.json`,JSON.stringify(results,null,2));await page.close();
 }
}finally{await browser.close();}
assert(results.every(r=>r.pass),JSON.stringify(results.filter(r=>!r.pass).map(r=>({side:r.side,scenario:r.scenario,motion:r.motion,error:r.error}))));
