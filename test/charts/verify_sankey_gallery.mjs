import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const [url,output]=process.argv.slice(2);
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const states=[],errors=[],scripts=[],reads=[];
try{
  const page=await browser.newPage({viewport:{width:1280,height:1000},reducedMotion:'reduce'});
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('response',r=>{if(/\.js$/.test(r.url()))reads.push(r.body().then(bytes=>scripts.push({url:r.url(),sha256:createHash('sha256').update(bytes).digest('hex')})));});
  await page.goto(url);await page.waitForTimeout(4000);
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(400);
  for(const quarter of ['Q3','Q2']){
    if(quarter==='Q2'){await page.getByRole('button',{name:'Q2',exact:true}).click();await page.waitForTimeout(500);}
    assert.equal(await page.getByRole('table',{name:`Income statement, ${quarter} data`}).count(),1);
    assert.equal(await page.getByRole('button',{name:quarter==='Q3'?'Subscriptions. $70M':'Subscriptions. $62M',exact:true}).count(),1);
    await page.getByRole('button',{name:/^Subscriptions\./}).click();
    await page.keyboard.press('ArrowRight');await page.waitForTimeout(400);
    const state=await page.evaluate(()=>({url:location.href,focused:document.activeElement?.getAttribute('aria-label')||document.activeElement?.textContent,probe:globalThis.__beuiCapture,text:document.body.innerText}));
    assert.match(state.focused,/^Revenue\./);states.push({quarter,...state});
    await page.screenshot({path:`${output}/${quarter}.png`});
    await page.keyboard.press('Escape');
  }
  assert.deepEqual(errors,[]);
  await Promise.all(reads);
  const expected=JSON.parse(await readFile('docs/proof/v3-parity/charts/sankey/builds-release/provenance.json'));
  assert.equal(scripts.find(s=>s.url===new URL('main.dart.js',url).href)?.sha256,expected.gallery.sha256);
  await writeFile(`${output}/result.json`,JSON.stringify({passed:true,states,errors,scripts},null,2));
}finally{await browser.close();}
