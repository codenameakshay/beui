import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const side=process.argv[2],run=process.argv[3]??'v1';
const output=`docs/proof/v3-parity/charts/round4-bump/narrow-${side}-${run}`;
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const states=[];
try{
  for(const reducedMotion of ['reduce','no-preference'])for(const touch of [false,true]){
    const context=await browser.newContext({viewport:{width:390,height:600},hasTouch:touch,reducedMotion,colorScheme:'dark'});
    const page=await context.newPage();
    await page.goto(`http://127.0.0.1:18115/${side}/?variant=narrow&theme=dark`,{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(2500);
    if(side!=='source')await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(100);
    if(touch){
      const cdp=await context.newCDPSession(page);
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:300,y:180}]});
      for(const x of [280,260,240,220,200,180,160,140,120,100]){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:180}]});await page.waitForTimeout(30);}
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    }else{
      for(let i=0;i<7;i++){await page.keyboard.press('Tab');await page.waitForTimeout(60);}
    }
    await page.waitForTimeout(400);
    const value=await page.evaluate(()=>{
      const buttons=[...document.querySelectorAll('button,flt-semantics[role="button"]')];
      const node=buttons.find(x=>(x.getAttribute('aria-label')||x.textContent).startsWith('Studio, Sep: rank 1'));
      return {active:(document.activeElement.getAttribute('aria-label')||document.activeElement.textContent).trim().split('\n')[0],lastDot:node?.getBoundingClientRect().toJSON(),sourceScroll:document.querySelector('section[tabindex="0"]')?.scrollLeft,flutter:globalThis.__beuiCapture??null};
    });
    states.push({side,reducedMotion,touch,...value});
    await page.screenshot({path:`${output}/${reducedMotion}-${touch?'touch':'keyboard'}.png`});
    assert(value.lastDot,`${side} last dot exists`);
    assert(value.lastDot.x>=35&&value.lastDot.x+value.lastDot.width<=356,`${side} last dot scrolls into the native viewport`);
    if(!touch)assert.equal(value.active,'Studio, Sep: rank 1');
    await context.close();
  }
}finally{
  await writeFile(`${output}/states.json`,JSON.stringify(states,null,2),{flag:'wx'});
  await browser.close();
}
