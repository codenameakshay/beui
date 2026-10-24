import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const root=import.meta.dirname;
const output=process.argv[2] || 'source-observations';
await mkdir(join(root,output));
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const results=[];
try {
  for (const reducedMotion of ['no-preference','reduce']) for (const theme of ['light','dark']) for (const [variant,labels] of [['pill',['Overview','Activity','Settings']],['segment',['Day','Week','Month']],['underline',['All','Open','Closed']]]) {
    const context=await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,colorScheme:theme,reducedMotion});
    const page=await context.newPage();
    await page.goto('https://beui.dev/components/motion/tabs');
    await page.waitForTimeout(2200);
    await page.getByRole('tab',{name:`${theme==='light'?'Light':'Dark'} theme`,exact:true}).click();
    await page.waitForTimeout(700);
    const list=page.locator('div.flex.items-center.justify-center.py-10 [role=tablist]').filter({has:page.getByRole('tab',{name:labels[0],exact:true})}).filter({hasNot:page.getByRole('tab',{name:'Analytics',exact:true})});
    assert.equal(await list.count(),1);
    await list.getByRole('tab',{name:labels[1],exact:true}).click();
    await page.keyboard.press('End');
    await page.waitForTimeout(900);
    const id=`source-${theme}-${reducedMotion}-${variant}`;
    await page.screenshot({path:join(root,output,`${id}-end.png`)});
    const state=()=>list.evaluate(list=>[...list.querySelectorAll('[role=tab]')].map(e=>({text:e.textContent,selected:e.getAttribute('aria-selected'),focused:e===document.activeElement,focusVisible:e.matches(':focus-visible'),tabIndex:e.tabIndex,rect:e.getBoundingClientRect().toJSON(),style:{outline:getComputedStyle(e).outline,outlineOffset:getComputedStyle(e).outlineOffset,background:getComputedStyle(e).backgroundColor,boxShadow:getComputedStyle(e).boxShadow,borderRadius:getComputedStyle(e).borderRadius,font:getComputedStyle(e).font}})));
    const end=await state();
    assert.ok(end.find(b=>b.selected==='true').text.startsWith(labels[2]));
    assert.equal(end.filter(b=>b.tabIndex===0).length,1);
    await page.keyboard.press('ArrowLeft');
    await page.waitForTimeout(900);
    const left=await state();
    assert.ok(left.find(b=>b.selected==='true').text.startsWith(labels[1]));
    await page.screenshot({path:join(root,output,`${id}-left.png`)});
    results.push({id,theme,reducedMotion,variant,revision:'unknown live deployment; pinned correspondence a76e57c9bbc2837e96420b2610e9c82a3271bb05',end,left});
    await writeFile(join(root,output,'results.json'),JSON.stringify(results,null,2));
    console.log(id,end.find(b=>b.focused)?.style);
    await context.close();
  }
} finally {await browser.close();}
