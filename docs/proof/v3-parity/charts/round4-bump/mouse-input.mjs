import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const side=process.argv[2],run=process.argv[3]??'v1';
const output=`docs/proof/v3-parity/charts/round4-bump/mouse-${side}-${run}`;
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const states=[];
try{
  for(const reducedMotion of ['reduce','no-preference']){
    const page=await browser.newPage({viewport:{width:800,height:600},reducedMotion,colorScheme:'dark'});
    await page.goto(`http://127.0.0.1:18115/${side}/?theme=dark`,{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(2500);
    if(side!=='source')await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(100);
    async function state(event,{pin,readout}={}){
      await page.waitForTimeout(300);
      const value=await page.evaluate(()=>{
        const nodes=[...document.querySelectorAll('button,flt-semantics[role="button"]')];
        const pinned=nodes.filter(x=>(x.getAttribute('aria-label')||x.textContent).startsWith('Highlight ')&&(x.getAttribute('aria-pressed')??x.getAttribute('aria-current'))==='true').map(x=>(x.getAttribute('aria-label')||x.textContent).split('\n')[0]);
        return {pinned,text:document.body.textContent,active:(document.activeElement.getAttribute('aria-label')||document.activeElement.textContent).split('\n')[0]};
      });
      states.push({side,reducedMotion,event,...value});
      await page.screenshot({path:`${output}/${reducedMotion}-${states.length}.png`});
      assert.deepEqual(value.pinned,pin?[`Highlight ${pin}`]:[]);
      if(readout===false)assert(!value.text.includes('No previous rank')&&!value.text.includes('Previously #'));
      if(typeof readout==='string')assert(value.text.includes(readout));
    }
    await page.mouse.move(137.83,249.14);await state('hover',{readout:'No previous rank'});
    await page.mouse.click(137.83,249.14);await state('click-pin-dismiss',{pin:'Studio',readout:false});
    await page.mouse.move(10,10);await state('pointer-exit',{pin:'Studio',readout:false});
    await page.keyboard.press('Tab');await state('native-tab-after-click',{pin:'Studio',readout:'Previously #4 in Apr'});
    await page.keyboard.press('Escape');await state('escape',{readout:false});
    const box=await page.getByRole('button',{name:'Highlight Canvas',exact:true}).boundingBox();
    await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await state('legend-hover',{readout:false});
    await page.mouse.click(box.x+box.width/2,box.y+box.height/2);await state('legend-click',{pin:'Canvas',readout:false});
    await page.mouse.move(10,10);await page.keyboard.press('Tab');await state('legend-native-tab',{pin:'Canvas',readout:false});
    assert.equal(states.at(-1).active,'Highlight Layers');
    await page.close();
  }
}finally{await browser.close();await writeFile(`${output}/states.json`,JSON.stringify(states,null,2),{flag:'wx'});}
