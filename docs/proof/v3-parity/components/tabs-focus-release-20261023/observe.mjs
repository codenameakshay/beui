import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const root=import.meta.dirname;
const output=process.argv[2] || 'native-checkpoints';
await mkdir(join(root,output));
const variants=[
  {name:'pill',labels:['Overview','Activity','Settings'],top:287.5,x:552.26,y:303.5,tabs:{before:1,after:1}},
  {name:'segment',labels:['Day','Week','Month'],top:511.5,x:503.85,y:527.5,tabs:{before:10,after:3}},
  {name:'underline',labels:['All','Open','Closed'],top:695.5,x:490.63,y:717.5,tabs:{before:0,after:0}},
];
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const results=[];
try {
  for (const reducedMotion of ['no-preference','reduce']) for (const theme of ['light','dark']) for (const phase of ['before','after']) for (const variant of variants) for (const checkpoint of ['end','left','keyboard-only']) {
    const context=await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,colorScheme:theme,reducedMotion});
    const page=await context.newPage();
    const port=phase==='before'?8112:8113;
    const url=`http://127.0.0.1:${port}/?slug=tabs&theme=${theme}&color=Blue&previewWidth=592&captureProbe=1`;
    await page.goto(url);
    await page.waitForFunction(()=>globalThis.__beuiCapture);
    await page.waitForTimeout(1800);
    const probe=await page.evaluate(()=>globalThis.__beuiCapture);
    assert.equal(probe.disableAnimations,reducedMotion==='reduce');
    const events=[];
    if (checkpoint==='keyboard-only') {
      if (variant.name==='underline'||variant.name==='segment') {
        const count=variant.name==='underline'?1:phase==='before'?7:3;
        for(let i=0;i<count;i++) {await page.keyboard.press('Shift+Tab');events.push('Shift+Tab');await page.waitForTimeout(100);}
      }
      else for (let i=0;i<variant.tabs[phase];i++) {await page.keyboard.press('Tab');events.push('Tab');await page.waitForTimeout(100);}
    } else {
      await page.mouse.move(variant.x,variant.y);
      await page.mouse.down();
      await page.waitForTimeout(180);
      await page.mouse.up();
      await page.mouse.move(100,100);
      events.push('move middle','down','up','move outside');
    }
    await page.keyboard.press('End');events.push('End');
    if (checkpoint==='left') {await page.keyboard.press('ArrowLeft');events.push('ArrowLeft');}
    await page.waitForTimeout(900);
    const id=`${phase}-${theme}-${reducedMotion}-${variant.name}-${checkpoint}`;
    await page.screenshot({path:join(root,output,`${id}.png`)});
    const activeBeforeObservation=await page.evaluate(()=>document.activeElement?.outerHTML);
    await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
    await page.waitForTimeout(200);
    const buttons=await page.locator('flt-semantics[role=button]').evaluateAll((es,top)=>es.map(e=>({name:e.textContent,selected:e.getAttribute('aria-current'),rect:e.getBoundingClientRect().toJSON()})).filter(e=>Math.abs(e.rect.y-top)<0.1),variant.top);
    const selected=buttons.filter(b=>b.selected==='true').map(b=>b.name);
    const expected=checkpoint==='keyboard-only'||(phase==='after'&&checkpoint==='end')?variant.labels[2]:variant.labels[1];
    const result={id,url,probe,events,expected,selected,buttons,activeBeforeObservation,screenshot:`${output}/${id}.png`,observation:'Fresh context. Native input and screenshot before semantics. Semantics enabled only at the final checkpoint to read selection. Tab preparation waits 100ms between presses.'};
    results.push(result);
    await writeFile(join(root,output,'results.json'),JSON.stringify(results,null,2));
    assert.deepEqual(selected,[expected],id);
    console.log(id,selected);
    await context.close();
  }
} finally {await browser.close();}
