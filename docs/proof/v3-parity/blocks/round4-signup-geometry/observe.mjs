import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const output=join(import.meta.dirname,process.argv[2]);
const theme=process.argv[3]??'light';
const motion=process.argv[4]??'no-preference';
assert(['light','dark'].includes(theme));
assert(['reduce','no-preference'].includes(motion));
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const results=[];
try {
 for(const source of (process.env.CANDIDATE_ONLY==='1'?[false]:[true,false])) {
  const id=(source?'source-':'candidate-')+theme;const dir=join(output,id);await mkdir(dir);
  const page=await browser.newPage({viewport:{width:1280,height:1400},deviceScaleFactor:1,colorScheme:theme,reducedMotion:motion});
  const result={id,theme,motion,states:[],responses:[],errors:[],requests:[],failedRequests:[]};results.push(result);const reads=[];
  page.on('request',r=>result.requests.push(r.url()));
  page.on('requestfailed',r=>result.failedRequests.push({url:r.url(),failure:r.failure()}));
  page.on('pageerror',e=>result.errors.push(String(e)));
  page.on('response',r=>{if(/main.dart.js|\.ttf/.test(r.url()))reads.push(r.body().then(b=>result.responses.push({url:r.url(),status:r.status(),bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')})));});
  try {
   await page.goto(source?'https://beui.dev/components/blocks/signup-form':`${process.env.CANDIDATE_BASE??"http://127.0.0.1:18118"}/?slug=signup-form&theme=${theme}&previewWidth=592&captureProbe=1&palette=source-default-a76e57c9`);
   if(source) await page.getByRole('tab',{name:theme==='light'?'Light theme':'Dark theme',exact:true}).click();
   else {await page.waitForFunction(()=>!!globalThis.__beuiCapture);await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());result.probe=await page.evaluate(()=>globalThis.__beuiCapture);}
   await page.waitForTimeout(1800);
   const state=async name=>{await page.screenshot({path:join(dir,name+'.png')});result.states.push({name,text:await page.locator('body').innerText(),inputs:await page.locator('input').evaluateAll(es=>es.map(e=>({placeholder:e.placeholder,value:e.value,type:e.type,disabled:e.disabled,readOnly:e.readOnly,rect:e.getBoundingClientRect().toJSON()}))),focus:await page.evaluate(()=>document.activeElement?.outerHTML)});};
   const placeholders=['Ada Lovelace','you@example.com','At least 8 characters','Re-enter your password'];
   if(!source) assert.equal(await page.locator('input').count(),4);
   const field=p=>source?page.getByPlaceholder(p,{exact:true}):page.locator('input').nth(placeholders.indexOf(p));
   const submit=()=>page.getByRole('button',{name:'Create account',exact:true});
   await state('rest');await submit().click();await page.waitForTimeout(400);await state('invalid');
   assert((await page.locator('body').innerText()).includes('Enter your name.'));
   const enter=async (placeholder,value)=>{
    await field(placeholder).click();
    await page.waitForTimeout(250);
    await page.keyboard.press('Meta+A');
    await page.keyboard.type(value,{delay:30});
    await page.waitForTimeout(200);
    assert.equal(await field(placeholder).inputValue(),value);
   };
   await enter('Ada Lovelace','Ada Lovelace');await state('name-entered');
   await enter('you@example.com','taken@example.com');
   await enter('At least 8 characters','ExamplePassword123!');
   await enter('Re-enter your password','ExamplePassword123!');await state('values-entered');
   result.roles=await page.locator('[role]').evaluateAll(es=>es.map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:e.textContent,rect:e.getBoundingClientRect().toJSON()})));
   await page.getByRole('button',{name:'Show password',exact:true}).click();
   await page.waitForFunction(()=>[...document.querySelectorAll('input')].some(e=>e.placeholder==='At least 8 characters'&&e.type==='text'));
   assert.equal(await field('At least 8 characters').getAttribute('type'),'text');await state('revealed');
   await page.getByRole('checkbox',{name:'I agree to the Terms and Privacy Policy',exact:true}).click();
   await submit().click();await page.waitForTimeout(200);await state('busy');
   await page.getByText('That email is already registered.',{exact:true}).waitFor();await state('rejected');
   await enter('you@example.com','ada@example.com');await submit().click();
   await page.getByRole('button',{name:'Account created',exact:true}).waitFor();await state('success');
   await field('Re-enter your password').click();await page.waitForTimeout(250);
   for(let n=0;n<3;n++){await page.keyboard.press('Tab');await page.waitForTimeout(100);}
   await state('footer-keyboard');
   assert.equal(await page.evaluate(()=>document.activeElement?.textContent?.trim()),'Sign in');
   await page.keyboard.press('Enter');await page.waitForTimeout(150);
   assert.equal(new URL(page.url()).pathname,source?'/components/blocks/signup-form':'/');result.pass=true;
  } catch(e) {result.error=String(e);await page.screenshot({path:join(dir,'failure.png')});}
  await Promise.all(reads);await writeFile(join(dir,'observations.json'),JSON.stringify(result,null,2));await page.close();
 }
} finally {await writeFile(join(output,'results.json'),JSON.stringify(results,null,2));await Promise.race([browser.close(),new Promise(resolve=>setTimeout(resolve,5000))]);}
process.exitCode=results.every(r=>r.pass)?0:1;
setTimeout(()=>process.exit(process.exitCode),1000).unref();
assert(results.every(r=>r.pass));
