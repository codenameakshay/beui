import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const [sourceUrl,candidateUrl,output]=process.argv.slice(2);
await mkdir(output);
const states=[];
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
try{
for(const reducedMotion of ['no-preference','reduce']) for(const source of [true,false]){
  const page=await browser.newPage({viewport:{width:1280,height:800},reducedMotion,hasTouch:true});
  const prefix=`${source?'source':'after'}-${reducedMotion}`;
  await page.goto(`${source?sourceUrl:candidateUrl}?theme=${reducedMotion==='reduce'?'light':'dark'}`);await page.waitForTimeout(3000);
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);
  const node=name=>page.getByRole('button',{name:new RegExp(`^${name}\\.`)});
  const remember=async(action)=>{
    await page.waitForTimeout(450);
    const state=await page.evaluate(source=>({focused:{text:document.activeElement?.getAttribute('aria-label')||document.activeElement?.textContent,tag:document.activeElement?.tagName,role:document.activeElement?.getAttribute('role')},nodeTabStops:[...document.querySelectorAll('button,[role=button]')].filter(e=>e.tabIndex===0&&/^(Subscriptions|Services|Marketplace|Revenue|Gross profit|Operating profit|R&D|Sales & marketing|G&A|Cost of revenue)\./.test(e.getAttribute('aria-label')||e.textContent)).map(e=>e.getAttribute('aria-label')||e.textContent),tooltips:[...document.querySelectorAll(source?'[role=tooltip]':'flt-semantics')].filter(e=>source||/^(Subscriptions|Services|Marketplace|Revenue|Gross profit|Operating profit|R&D|Sales & marketing|G&A|Cost of revenue)\s+\$/.test(e.textContent)).filter(e=>source||!e.querySelector('flt-semantics')).map(e=>({text:e.textContent,rect:e.getBoundingClientRect().toJSON()})),text:document.body.innerText,probe:globalThis.__beuiCapture}),source);
    states.push({source,reducedMotion,action,...state});
    await page.screenshot({path:`${output}/${prefix}-${action}.png`});return state;
  };
  await remember('idle');
  assert.equal(await page.getByRole('table',{name:'Income statement, Q3 data'}).count(),1);
  assert.equal(await page.getByRole('row').count(),10);
  assert.equal(await page.getByRole('columnheader').count(),3);
  await node('Subscriptions').click();
  let state=await remember('click');assert.match(state.focused.text,/^Subscriptions/);
  for(const [key,name] of [['ArrowRight','Revenue'],['ArrowRight','Gross profit'],['End','Operating profit'],['Home','Subscriptions'],['ArrowDown','Services']]){
    await page.keyboard.press(key);state=await remember(key+'-'+name.replaceAll(' ','_'));assert.match(state.focused.text,new RegExp(`^${name}`));assert.equal(state.tooltips.length,1,JSON.stringify(state));assert.equal(state.nodeTabStops.length,1);
  }
  await page.keyboard.press('Escape');state=await remember('escape');assert.equal(state.tooltips.length,0);assert.match(state.focused.text,/^Services/);
  await page.keyboard.press('ArrowRight');state=await remember('reopen');assert.equal(state.tooltips.length,1);
  await page.keyboard.press('Shift+Tab');state=await remember('shift-tab-out');assert.doesNotMatch(state.focused.text||'',/^Revenue\./);assert.equal(state.tooltips.length,0);
  await page.keyboard.press('Tab');state=await remember('tab-back');assert.match(state.focused.text,/^Revenue\./);assert.equal(state.tooltips.length,1);
  await page.keyboard.press('Tab');state=await remember('tab-out');assert.doesNotMatch(state.focused.text||'',/^(Subscriptions|Services|Marketplace|Revenue|Gross profit|Operating profit|R&D|Sales & marketing|G&A|Cost of revenue)\./);assert.equal(state.tooltips.length,0);
  await page.mouse.click(1100,700);state=await remember('outside');assert.equal(state.tooltips.length,0);
  const box=await node('Gross profit').boundingBox();await page.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);state=await remember('touch-release');assert.equal(state.tooltips.length,1);
  await page.touchscreen.tap(1100,700);state=await remember('touch-outside');assert.equal(state.tooltips.length,0);
  await page.mouse.move(260,380);state=await remember('mouse-after-touch');
  await page.mouse.move(50,50);await page.waitForTimeout(300);
  await page.mouse.click(280,232);state=await remember('q2');assert.match(state.text,/\$62M/);
  await node('Subscriptions').click();state=await remember('q2-click');assert.match(state.focused.text,/^Subscriptions\./);
  await page.keyboard.press('ArrowRight');state=await remember('q2-arrow');assert.match(state.focused.text,/^Revenue\./);assert.equal(state.nodeTabStops.length,1);
  await page.keyboard.press('Escape');await remember('q2-escape');
  await page.setViewportSize({width:390,height:800});state=await remember('narrow');
  const beforeX=(await node('Gross profit').boundingBox()).x;
  const cdp=await page.context().newCDPSession(page);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:320,y:450}]});
  for(let x=300;x>=60;x-=20){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:450}]});await page.waitForTimeout(25);}
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await page.waitForTimeout(500);
  const afterX=(await node('Gross profit').boundingBox()).x;
  assert.ok(afterX<beforeX-50,`Touch scroll did not move plot ${beforeX} -> ${afterX}`);
  await remember('narrow-touch-scroll');
  await page.close();
}
for(const source of [true,false]){
  const page=await browser.newPage({viewport:{width:1280,height:800},reducedMotion:'reduce'});
  await page.goto(source?sourceUrl:candidateUrl);await page.waitForTimeout(3000);
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);
  for(const [action,x,y,expected] of [['hover-node',262,380,/Subscriptions/],['hover-flow',400,380,/Subscriptions.*Revenue/s],['hover-exit',50,50,null]]){
    await page.mouse.move(x,y);await page.waitForTimeout(450);
    const text=await page.evaluate(source=>[...document.querySelectorAll(source?'[role=tooltip]':'flt-semantics')].filter(e=>source||(!e.querySelector('flt-semantics')&&/^Subscriptions(?:\s+\$| → Revenue\s+\$)/.test(e.textContent))).map(e=>e.textContent).join('\n'),source);
    if(expected) assert.match(text,expected);
    else if(source) assert.equal(await page.getByRole('tooltip').count(),0);
    else assert.doesNotMatch(text,/Subscriptions → Revenue|Subscriptions\s+\$70M\s+To/);
    states.push({source,action,text});
    await page.screenshot({path:`${output}/${source?'source':'after'}-${action}.png`});
  }
  await page.close();
}
await writeFile(`${output}/result.json`,JSON.stringify({passed:true,states:states.length},null,2));
}finally{await writeFile(`${output}/states.json`,JSON.stringify(states,null,2));await browser.close();}
