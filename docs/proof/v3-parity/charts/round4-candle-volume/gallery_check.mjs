import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

const root = `docs/proof/v3-parity/charts/round4-candle-volume/${process.argv[2] ?? 'gallery-v13-native'}`;
await mkdir(root);
const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const rows = [];
try {
  for(const [width,height] of [[1280,1000],[375,700]]) {
    const context = await browser.newContext({viewport:{width,height},reducedMotion:'reduce',colorScheme:'light',deviceScaleFactor:1});
    const page = await context.newPage();
    const inputs = [];
    const scripts = [];
    const pending = [];
    page.on('response',response=>{if(response.url().endsWith('main.dart.js'))pending.push(response.body().then(bytes=>scripts.push({url:response.url(),sha256:createHash('sha256').update(bytes).digest('hex')})));});
    await page.addInitScript(()=>{
      globalThis.__galleryInputs=[];
      for(const type of ['pointerdown','pointerup','keydown','wheel'])document.addEventListener(type,e=>globalThis.__galleryInputs.push({type,key:e.key,trusted:e.isTrusted}),true);
    });
    await page.goto('http://127.0.0.1:18114/?slug=volume-profile&theme=light&previewWidth=576&captureProbe=1',{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(3000);
    await page.locator('flt-semantics-placeholder').evaluateAll(nodes=>nodes.forEach(n=>n.click()));
    await page.waitForTimeout(500);
    await writeFile(`${root}/${width}-initial.json`,JSON.stringify(await page.evaluate(()=>({probe:globalThis.__beuiCapture,roles:[...document.querySelectorAll('[role]')].map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:e.textContent})),text:document.body.innerText})),null,2),{flag:'wx'});
    const initialCdp=await context.newCDPSession(page);
    const initialShot=await initialCdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    await writeFile(`${root}/${width}-initial.png`,Buffer.from(initialShot.data,'base64'),{flag:'wx'});
    for(const session of ['Previous','Week','Today']) {
      const tab=page.getByRole('button',{name:session,exact:true});
      const tabBox=await tab.boundingBox();
      assert(tabBox);
      await page.mouse.click(tabBox.x+tabBox.width/2,tabBox.y+tabBox.height/2);
      await page.waitForTimeout(600);
      const slider=page.getByRole('slider').last();
      const box=await slider.boundingBox();
      assert(box);
      await page.mouse.click(box.x+box.width*.4,Math.min(height-40,box.y+box.height*.45));
      await page.keyboard.press('Home');
      await page.waitForTimeout(400);
      const value=await slider.getAttribute('aria-valuetext');
      const volume={Previous:6,Week:75,Today:18}[session];
      assert(value.startsWith(`$64,000 to $64,100. ${volume} BTC.`),value);
      await page.mouse.move(width-30,height-30);
      await page.mouse.wheel(0,500);
      await page.waitForTimeout(600);
      const summary=page.getByText('Total volume',{exact:true});
      const summaryBox=await summary.boundingBox();
      assert(summaryBox && summaryBox.y>=0 && summaryBox.y+summaryBox.height<=height,JSON.stringify(summaryBox));
      const cdp=await context.newCDPSession(page);
      const shot=await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
      await writeFile(`${root}/${width}-${session}.png`,Buffer.from(shot.data,'base64'),{flag:'wx'});
      rows.push({width,height,session,value,summaryBox,probe:await page.evaluate(()=>globalThis.__beuiCapture)});
      await page.mouse.wheel(0,-500);
      await page.waitForTimeout(300);
    }
    inputs.push(...await page.evaluate(()=>globalThis.__galleryInputs));
    assert(inputs.length && inputs.every(input=>input.trusted));
    await Promise.all(pending);
    await writeFile(`${root}/${width}.json`,JSON.stringify({scripts,inputs,rows:rows.filter(row=>row.width===width)},null,2),{flag:'wx'});
    await context.close();
  }
} finally {await browser.close();}
console.log(JSON.stringify(rows,null,2));
