import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const output=`${import.meta.dirname}/${process.argv[2]}`;
await mkdir(output);
const expected=JSON.parse(await readFile(`${import.meta.dirname}/build.json`)).releaseMainJsSha256;
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const results=[];
try {
 for(const motion of ['no-preference','reduce']) {
  const page=await browser.newPage({viewport:{width:1280,height:1000},reducedMotion:motion});
  const result={motion,scripts:[],errors:[]};results.push(result);const reads=[];
  page.on('pageerror',e=>result.errors.push(String(e)));
  page.on('response',r=>{if(r.url().endsWith('main.dart.js'))reads.push(r.body().then(b=>result.scripts.push(createHash('sha256').update(b).digest('hex'))));});
  await page.goto('http://127.0.0.1:18118/?slug=composition-chart&theme=light&color=Blue&captureProbe=1');
  await page.waitForFunction(()=>globalThis.__beuiCapture);
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  const slider=page.getByRole('slider').first();await slider.waitFor();
  const box=await slider.boundingBox();assert(box);
  await page.mouse.move(box.x+box.width*.55,box.y+box.height*.5);
  await page.waitForTimeout(800);
  result.sliders=await page.getByRole('slider').evaluateAll(es=>es.map(e=>({value:e.getAttribute('aria-valuetext'),parent:e.parentElement?.getAttribute('aria-label')})));
  result.probe=await page.evaluate(()=>globalThis.__beuiCapture);
  assert.equal(result.probe.disableAnimations,motion==='reduce');
  assert.equal(result.probe.platformDisableAnimations,motion==='reduce');
  assert.equal(result.sliders[0].value,'Aug 20');
  assert(result.sliders[0].parent.includes('Organic search: 4,958 visits (38.6%)'));
  assert(result.sliders[0].parent.includes('Other: 286 visits (2.2%)')); 
  await page.screenshot({path:`${output}/${motion}.png`});
  await Promise.all(reads);assert(result.scripts.includes(expected));assert.equal(result.errors.length,0);
  result.pass=true;await page.close();
 }
}finally {await writeFile(`${output}/results.json`,JSON.stringify(results,null,2));await browser.close();}
