import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root='docs/proof/v3-parity/charts/round4-candle-volume/gallery-candle-v13-native';
await mkdir(root);
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const rows=[];
try{
  for(const width of [1280,375]){
    const context=await browser.newContext({viewport:{width,height:1000},reducedMotion:'reduce',colorScheme:'light',deviceScaleFactor:1});
    const page=await context.newPage();
    const scripts=[];const pending=[];
    page.on('response',response=>{if(response.url().endsWith('main.dart.js'))pending.push(response.body().then(bytes=>scripts.push({url:response.url(),sha256:createHash('sha256').update(bytes).digest('hex')})));});
    await page.addInitScript(()=>{globalThis.__inputs=[];for(const type of ['pointerdown','pointerup','keydown'])document.addEventListener(type,e=>globalThis.__inputs.push({type,key:e.key,trusted:e.isTrusted}),true);});
    await page.goto('http://127.0.0.1:18114/?slug=candlestick-chart&theme=light&previewWidth=576&captureProbe=1',{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(3000);
    await page.locator('flt-semantics-placeholder').evaluateAll(nodes=>nodes.forEach(n=>n.click()));
    await page.waitForTimeout(500);
    const click=async name=>{const box=await page.getByRole('button',{name,exact:true}).boundingBox();assert(box);await page.mouse.click(box.x+box.width/2,box.y+box.height/2);await page.waitForTimeout(300);};
    await click('Pause');
    const slider=page.getByRole('slider').last();
    const paused=await slider.getAttribute('aria-valuetext');
    await page.waitForTimeout(1100);
    assert.equal(await slider.getAttribute('aria-valuetext'),paused);
    await click('Step');
    const stepped=await slider.getAttribute('aria-valuetext');
    assert.notEqual(stepped,paused);
    const box=await slider.boundingBox();assert(box);
    await page.mouse.click(box.x+box.width*.3,box.y+box.height*.3);
    await page.keyboard.press('Home');await page.waitForTimeout(300);
    const home=await slider.getAttribute('aria-valuetext');
    assert(home.startsWith('12:00: open 2,380.00'),home);
    await page.keyboard.press('End');await page.waitForTimeout(300);
    assert.equal(await slider.getAttribute('aria-valuetext'),stepped);
    const cdp=await context.newCDPSession(page);const shot=await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    await writeFile(`${root}/${width}.png`,Buffer.from(shot.data,'base64'),{flag:'wx'});
    const probe=await page.evaluate(()=>globalThis.__beuiCapture);
    assert.equal(probe.disableAnimations,true);
    const inputs=await page.evaluate(()=>globalThis.__inputs);assert(inputs.length&&inputs.every(input=>input.trusted));
    await Promise.all(pending);rows.push({width,paused,stepped,home,probe,scripts,inputs});await context.close();
  }
}finally{await browser.close();}
await writeFile(`${root}/results.json`,JSON.stringify(rows,null,2),{flag:'wx'});
console.log(JSON.stringify(rows,null,2));
