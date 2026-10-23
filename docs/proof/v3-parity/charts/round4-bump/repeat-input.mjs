import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const side=process.argv[2];
const output=`docs/proof/v3-parity/charts/round4-bump/repeat-${side}-${process.argv[3]}`;
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const states=[];
try {
  for(const reducedMotion of ['no-preference','reduce']){
    const page=await browser.newPage({viewport:{width:800,height:600},reducedMotion,colorScheme:'dark'});
    await page.addInitScript(()=>{
      globalThis.__bumpKeys=[];
      for(const type of ['keydown','keyup'])window.addEventListener(type,event=>globalThis.__bumpKeys.push({type,key:event.key,repeat:event.repeat,isTrusted:event.isTrusted,timeStamp:event.timeStamp}),true);
    });
    const scripts=[],reads=[];
    page.on('response',response=>{if(/\.js(?:\?|$)/.test(response.url()))reads.push(response.body().then(bytes=>scripts.push({url:response.url(),sha256:createHash('sha256').update(bytes).digest('hex')})));});
    await page.goto(`http://127.0.0.1:18115/${side}/?theme=dark`);
    await page.waitForTimeout(2000);
    if(side!=='source')await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
    await page.keyboard.press('Tab');await page.waitForTimeout(100);
    await page.keyboard.press('Tab');await page.waitForTimeout(100);
    for(const control of ['dot','legend']){
      if(control==='legend')for(let i=0;i<30;i++){await page.keyboard.press('Tab');await page.waitForTimeout(60);}
      async function state(action,expected){
        await page.waitForTimeout(180);
        const value=await page.evaluate(()=>{
          const name=x=>(x?.getAttribute('aria-label')||x?.textContent||'').trim().split('\n')[0];
          const button=[...document.querySelectorAll('button,flt-semantics[role="button"]')].find(x=>name(x)==='Highlight Studio');
          return {active:name(document.activeElement),pressed:button.getAttribute('aria-pressed'),current:button.getAttribute('aria-current'),keys:globalThis.__bumpKeys,flutter:globalThis.__beuiCapture??null};
        });
        states.push({side,reducedMotion,control,action,...value});
        await page.screenshot({path:`${output}/${reducedMotion}-${control}-${action}.png`});
        assert.equal(value.active,control==='dot'?'Studio, Apr: rank 4':'Highlight Studio');
        assert.equal(value.pressed??value.current,String(expected));
      }
      await page.keyboard.down('Enter');await state('enter-down',true);
      await page.keyboard.down('Enter');await state('enter-repeat',false);
      await page.keyboard.up('Enter');await state('enter-up',false);
      await page.keyboard.down('Space');await state('space-down',false);
      await page.keyboard.up('Space');await state('space-up',true);
      await page.keyboard.press('Escape');await state('escape',false);
      await page.keyboard.press('Home');await state('home-after-escape',false);
    }
    const keys=await page.evaluate(()=>globalThis.__bumpKeys);
    assert(keys.every(x=>x.isTrusted));
    assert.equal(keys.filter(x=>x.type==='keydown'&&x.key==='Enter'&&x.repeat).length,2);
    await Promise.all(reads);
    await writeFile(`${output}/${reducedMotion}-events.json`,JSON.stringify({scripts,keys},null,2),{flag:'wx'});
    await page.close();
  }
}finally{
  await writeFile(`${output}/states.json`,JSON.stringify(states,null,2),{flag:'wx'});
  await browser.close();
}
