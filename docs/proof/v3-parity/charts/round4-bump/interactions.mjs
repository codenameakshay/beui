import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const side=process.argv[2], run=process.argv[3]??'v1';
const output=`docs/proof/v3-parity/charts/round4-bump/interactions-${side}-${run}`;
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const observations=[];
try {
  for(const reducedMotion of ['no-preference','reduce'])for(const touch of [false,true]){
    const context=await browser.newContext({viewport:{width:800,height:600},colorScheme:'dark',reducedMotion,hasTouch:touch});
    await context.addInitScript(()=>{
      globalThis.__nativeBumpEvents=[];
      for(const type of ['pointerdown','pointerup','click','keydown','keyup'])document.addEventListener(type,event=>globalThis.__nativeBumpEvents.push({type,key:event.key,pointerType:event.pointerType,isTrusted:event.isTrusted,timeStamp:event.timeStamp}),true);
    });
    const page=await context.newPage();
    const scripts=[],reads=[];
    page.on('response',response=>{if(/\.js(?:\?|$)/.test(response.url()))reads.push(response.body().then(bytes=>scripts.push({url:response.url(),sha256:createHash('sha256').update(bytes).digest('hex')})));});
    await page.goto(`http://127.0.0.1:18115/${side}/?theme=dark`,{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(2500);
    if(side!=='source')await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(150);
    async function state(event,expected){
      await page.waitForTimeout(250);
      const value=await page.evaluate(()=>{
        const name=element=>(element?.getAttribute('aria-label')||element?.textContent||'').trim().split('\n')[0];
        const nodes=[...document.querySelectorAll('button,flt-semantics[role="button"],flt-semantics[role="switch"]')];
        const legend=nodes.filter(element=>name(element).startsWith('Highlight ')).map(element=>({name:name(element),role:element.getAttribute('role')||element.tagName.toLowerCase(),pressed:element.getAttribute('aria-pressed'),current:element.getAttribute('aria-current'),checked:element.getAttribute('aria-checked')}));
        return {active:name(document.activeElement),legend,visibleText:document.body.textContent,tooltipText:[...document.querySelectorAll('[role="tooltip"]')].map(x=>x.textContent),flutter:globalThis.__beuiCapture??null,browserReducedMotion:matchMedia('(prefers-reduced-motion: reduce)').matches};
      });
      const studio=value.legend.find(x=>x.name==='Highlight Studio');
      const pinned=studio?.pressed??studio?.current??studio?.checked;
      const recorded={side,reducedMotion,touch,event,...value};
      observations.push(recorded);
      await page.screenshot({path:`${output}/${reducedMotion}-${touch?'touch':'keyboard'}-${observations.length}.png`});
      if(expected.active)assert.equal(value.active,expected.active,`${side} ${event} active`);
      if(expected.pinned!==undefined)assert.equal(pinned,String(expected.pinned),`${side} ${event} pin`);
      if(expected.text)assert(value.visibleText.includes(expected.text),`${side} ${event} visible readout`);
      if(expected.closed)assert(!value.visibleText.includes('Previously #')&&!value.visibleText.includes('No previous rank'),`${side} ${event} dismissed readout`);
      if(value.flutter)assert.equal(value.flutter.disableAnimations,reducedMotion==='reduce');
    }
    if(touch){
      for(const [index,pinned]of [true,false,true].entries()){
        await page.touchscreen.tap(137.83,249.14);
        await state(`touch-${index+1}`,{pinned,...(pinned?{text:'No previous rank'}:{closed:true})});
      }
    }else{
      await page.keyboard.press('Tab');await state('plot-tab',{active:'Product rankings plot, scroll horizontally for more periods'});
      await page.keyboard.press('Tab');await state('first-dot',{active:'Studio, Apr: rank 4',text:'No previous rank'});
      await page.keyboard.press('Tab');await state('next-dot',{active:'Studio, May: rank 3',text:'Previously #4 in Apr'});
      for(const key of ['Home','End','ArrowDown','ArrowRight']){await page.keyboard.press(key);await state(key,{active:'Studio, May: rank 3',pinned:false});}
      await page.keyboard.press('Enter');await state('enter-pin',{pinned:true});
      await page.keyboard.down('Space');await state('space-down',{pinned:true});
      await page.keyboard.up('Space');await state('space-up',{pinned:false});
      await page.keyboard.press('Escape');await state('escape',{closed:true,pinned:false});
      await page.keyboard.press('Enter');await state('enter-after-escape',{closed:true,pinned:true});
      await page.keyboard.press('Tab');await state('next-reopens',{active:'Studio, Jun: rank 2',text:'Previously #3 in May'});
      for(let i=0;i<28;i++){await page.keyboard.press('Tab');await page.waitForTimeout(60);}
      await state('legend-tab',{active:'Highlight Studio',pinned:true});
      await page.keyboard.press('Tab');await state('legend-next',{active:'Highlight Canvas',pinned:true});
      await page.keyboard.press('Escape');await state('legend-escape',{pinned:false,closed:true});
    }
    await Promise.all(reads);
    const events=await page.evaluate(()=>globalThis.__nativeBumpEvents);
    assert(events.filter(x=>x.type==='keydown'||x.type==='pointerdown').every(x=>x.isTrusted));
    await writeFile(`${output}/${reducedMotion}-${touch?'touch':'keyboard'}-events.json`,JSON.stringify({scripts,events},null,2),{flag:'wx'});
    await context.close();
  }
} finally {
  await writeFile(`${output}/states.json`,JSON.stringify(observations,null,2),{flag:'wx'});
  await browser.close();
}
