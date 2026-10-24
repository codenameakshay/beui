import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const output=join(import.meta.dirname,process.argv[2]);
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const results=[];
try {
 for(const source of [true,false]) {
  const id=source?'source-light':'candidate-light';const dir=join(output,id);await mkdir(dir);
  const page=await browser.newPage({viewport:{width:1280,height:1400},deviceScaleFactor:1,colorScheme:'light',reducedMotion:'no-preference'});
  const result={id,states:[],responses:[],errors:[]};results.push(result);const reads=[];
  page.on('pageerror',e=>result.errors.push(String(e)));
  page.on('response',r=>{if(/main.dart.js|\.ttf/.test(r.url()))reads.push(r.body().then(b=>result.responses.push({url:r.url(),status:r.status(),bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')})));});
  try {
   await page.goto(source?'https://beui.dev/components/blocks/signup-form':'http://127.0.0.1:18118/?slug=signup-form&theme=light&previewWidth=592&captureProbe=1');
   if(source) await page.getByRole('tab',{name:'Light theme',exact:true}).click();
   else {await page.waitForFunction(()=>!!globalThis.__beuiCapture);await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());result.probe=await page.evaluate(()=>globalThis.__beuiCapture);}
   await page.waitForTimeout(1800);
   const state=async name=>{await page.screenshot({path:join(dir,name+'.png')});result.states.push({name,text:await page.locator('body').innerText(),inputs:await page.locator('input').evaluateAll(es=>es.map(e=>({placeholder:e.placeholder,value:e.value,type:e.type,disabled:e.disabled,readOnly:e.readOnly}))),focus:await page.evaluate(()=>document.activeElement?.outerHTML)});};
   const field=p=>page.getByPlaceholder(p,{exact:true});
   const submit=()=>page.getByRole('button',{name:'Create account',exact:true});
   await state('rest');await submit().click();await page.waitForTimeout(400);await state('invalid');
   assert((await page.locator('body').innerText()).includes('Enter your name.'));
   await field('Ada Lovelace').fill('Ada Lovelace');await field('you@example.com').fill('taken@example.com');
   await field('At least 8 characters').fill('ExamplePassword123!');await field('Re-enter your password').fill('ExamplePassword123!');
   await page.getByRole('button',{name:'Show password',exact:true}).click();
   assert.equal(await field('At least 8 characters').getAttribute('type'),'text');await state('revealed');
   await page.getByRole('checkbox',{name:'I agree to the Terms and Privacy Policy',exact:true}).click();
   await submit().click();await page.waitForTimeout(200);await state('busy');
   await page.getByText('That email is already registered.',{exact:true}).waitFor();await state('rejected');
   await field('you@example.com').fill('ada@example.com');await submit().click();
   await page.getByText('Account created',{exact:true}).waitFor();await state('success');result.pass=true;
  } catch(e) {result.error=String(e);await page.screenshot({path:join(dir,'failure.png')});}
  await Promise.all(reads);await writeFile(join(dir,'observations.json'),JSON.stringify(result,null,2));await page.close();
 }
} finally {await writeFile(join(output,'results.json'),JSON.stringify(results,null,2));await browser.close();}
assert(results.every(r=>r.pass));
