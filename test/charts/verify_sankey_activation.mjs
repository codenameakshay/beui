import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const [sourceUrl,candidateUrl,output]=process.argv.slice(2);
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const states=[];
try{
  for(const source of [true,false]){
    const page=await browser.newPage({viewport:{width:1280,height:800},reducedMotion:'reduce',hasTouch:true});
    await page.goto(source?sourceUrl:candidateUrl);await page.waitForTimeout(3000);
    await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);
    const read=async action=>{
      await page.waitForTimeout(400);
      const text=await page.evaluate(source=>[...document.querySelectorAll(source?'[role=tooltip]':'flt-semantics')].filter(e=>source||(!e.querySelector('flt-semantics')&&/^(Subscriptions|Services)(?:\s+\$| → Revenue\s+\$)/.test(e.textContent))).map(e=>e.textContent).join('\n'),source);
      states.push({source,action,text});await page.screenshot({path:`${output}/${source?'source':'after'}-${action}.png`});return text;
    };
    await page.getByRole('button',{name:/^Subscriptions\./}).click();await page.keyboard.press('Escape');
    for(const key of ['Enter','Space']){await page.keyboard.press(key);assert.equal(await read(`closed-${key}`),'');}
    const cdp=await page.context().newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:262,y:380}]});
    assert.match(await read('touch-press'),/Subscriptions/);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:262,y:510}]});
    assert.match(await read('touch-drag'),/Subscriptions/);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    assert.match(await read('touch-release'),/Subscriptions/);
    await page.touchscreen.tap(50,50);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:400,y:380}]});
    assert.match(await read('flow-touch-press'),/^Subscriptions → Revenue/);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:400,y:510}]});
    assert.match(await read('flow-touch-drag'),/^Subscriptions → Revenue/);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    assert.match(await read('flow-touch-release'),/^Subscriptions → Revenue/);
    await page.close();
  }
  await writeFile(`${output}/result.json`,JSON.stringify({passed:true,states},null,2));
}finally{await browser.close();}
