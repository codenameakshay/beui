import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const states=[];
try {
  for(const deviceScaleFactor of [1,1.25,2]){
    const page=await browser.newPage({viewport:{width:800,height:600},deviceScaleFactor,reducedMotion:'reduce'});
    await page.goto('http://127.0.0.1:18115/source/?theme=dark');
    await page.waitForTimeout(1200);
    const state=await page.evaluate(()=>{
      const span=document.querySelector('button[aria-label="Studio, Apr: rank 4"]').lastElementChild;
      const css=getComputedStyle(span);
      return {dpr:devicePixelRatio,border:css.borderTopWidth,width:css.width,height:css.height,font:css.fontFamily,fontWeight:css.fontWeight,rect:span.getBoundingClientRect().toJSON()};
    });
    states.push(state);
    assert.equal(parseFloat(state.border),1);
    await page.close();
  }
}finally{
  await writeFile(`docs/proof/v3-parity/charts/round4-bump/source-border-metrics-${process.argv[2]}.json`,JSON.stringify(states,null,2),{flag:'wx'});
  await browser.close();
}
