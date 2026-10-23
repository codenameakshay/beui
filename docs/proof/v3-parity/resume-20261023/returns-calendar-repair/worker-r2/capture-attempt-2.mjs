import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const root=path.dirname(new URL(import.meta.url).pathname);
const attempt=process.argv[2]||'attempt-1';
await fs.mkdir(path.join(root,attempt));
const hash=b=>createHash('sha256').update(b).digest('hex');
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const reports=[];
try {
for(const target of ['source','candidate']) for(const reducedMotion of ['no-preference','reduce']) {
 const out=path.join(root,attempt,`${target}-${reducedMotion}`);await fs.mkdir(path.join(out,'original-frames'),{recursive:true});
 const context=await browser.newContext({viewport:{width:1000,height:800},deviceScaleFactor:1,reducedMotion,colorScheme:'light'});
 const page=await context.newPage();const reads=[],scripts=[],errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('response',r=>{if(/\.js(?:\?|$)/.test(r.url()))reads.push(r.body().then(async bytes=>{const sha256=hash(bytes);await fs.mkdir(path.join(root,'served-js'),{recursive:true});await fs.writeFile(path.join(root,'served-js',sha256+'.js'),bytes);scripts.push({url:r.url(),sha256,bytes:bytes.length});}));});
 await page.addInitScript(()=>{globalThis.__inputs=[];for(const type of ['keydown','keyup','pointerdown','pointerup','pointermove','click','focusin','focusout'])document.addEventListener(type,e=>globalThis.__inputs.push({type,key:e.key,isTrusted:e.isTrusted,x:e.clientX,y:e.clientY,time:performance.now(),tag:e.target.tagName,label:e.target.getAttribute?.('aria-label'),text:e.target.textContent?.slice(0,100)}),true)});
 await page.goto('http://127.0.0.1:18157/'+(target==='source'?'source/':'candidate/example/build/web/'));
 await page.waitForFunction(()=>globalThis.__fixture?.snapshot);
 await page.locator('flt-semantics-placeholder').evaluateAll(ns=>ns.forEach(n=>n.click()));
 await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(700);await page.mouse.move(10,10);
 const cdp=await context.newCDPSession(page);const frames=[],pending=[];
 cdp.on('Page.screencastFrame',e=>{const file=`original-frames/frame_${String(frames.length).padStart(6,'0')}.png`;const bytes=Buffer.from(e.data,'base64');frames.push({file,sha256:hash(bytes),metadata:e.metadata});pending.push(fs.writeFile(path.join(out,file),bytes),cdp.send('Page.screencastFrameAck',{sessionId:e.sessionId}));});
 await cdp.send('Page.startScreencast',{format:'png',everyNthFrame:1});
 const states=[],checks=[];
 const check=(name,ok,actual)=>{checks.push({name,pass:!!ok,actual});if(!ok)console.log('FAIL',target,reducedMotion,name,JSON.stringify(actual));};
 const capture=async(name,expected)=>{await page.waitForTimeout(450);const aria=await page.locator('body').ariaSnapshot();const observed=await page.evaluate(()=>({buttons:[...document.querySelectorAll('[role=button],button')].map(n=>({label:n.getAttribute('aria-label'),text:n.textContent,pressed:n.getAttribute('aria-pressed'),selected:n.getAttribute('aria-selected'),opacity:getComputedStyle(n.parentElement).opacity})),fixture:globalThis.__fixture,inputs:globalThis.__inputs,reduce:matchMedia('(prefers-reduced-motion: reduce)').matches,hover:matchMedia('(hover: hover) and (pointer: fine)').matches,identity:globalThis.__tracked?{connected:globalThis.__tracked.isConnected,sameFocused:globalThis.__tracked===document.activeElement,label:globalThis.__tracked.getAttribute('aria-label')}:null,focus:{tag:document.activeElement?.tagName,text:document.activeElement?.textContent,label:document.activeElement?.getAttribute('aria-label')}}));const png=Buffer.from((await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false})).data,'base64');await fs.writeFile(path.join(out,name+'.png'),png);const s={name,aria,...observed,screenshot:{file:name+'.png',sha256:hash(png)}};states.push(s);if(expected)for(const text of expected)check(name+': '+text,aria.includes(text),aria);return s;};
 const cell=(y,m)=>target==='source'?page.locator(`[data-return-cell="${y}-${m}"]`):page.getByRole('button',{name:new RegExp(' return ')}).nth(y*13+m);
 const point=async(locator,click=false)=>{const r=await locator.boundingBox();if(!r)throw Error('missing bounds');if(click)await page.mouse.click(r.x+r.width/2,r.y+r.height/2);else await page.mouse.move(r.x+r.width/2,r.y+r.height/2);await page.waitForTimeout(250)};
 const track=async()=>page.evaluate(()=>globalThis.__tracked=document.activeElement);
 const focusCell=async(y,m)=>{await page.keyboard.press('Escape');await point(cell(y,m),true);await page.mouse.move(10,10);await page.keyboard.press('Escape');await page.waitForTimeout(300);await track()};
 try {
 let s=await capture('rest');check('motion',s.reduce===(reducedMotion==='reduce')&&s.fixture.disableAnimations===s.reduce,s.fixture);
 await point(cell(1,2));await capture('hover-march');await page.mouse.move(10,10);await capture('hover-exit');
 await focusCell(1,2);await capture('before-missing');await page.keyboard.press('m');await capture('missing-focused');await page.keyboard.press('Tab');await capture('missing-next');await page.keyboard.press('i');await capture('months-reinserted');await page.keyboard.press('Shift+Tab');await capture('months-reverse');
 await focusCell(1,2);await capture('before-year-replace');await page.keyboard.press('r');await capture('year-replaced');await page.keyboard.press('Tab');await capture('replacement-next');await page.keyboard.press('i');await capture('year-reinserted');await page.keyboard.press('Tab');await capture('reinsert-next');
 await focusCell(1,12);await capture('before-year-remove');await page.keyboard.press('d');await capture('year-removed');await page.keyboard.press('Tab');await capture('removal-next');await page.keyboard.press('i');await capture('removed-year-reinserted');await page.keyboard.press('Tab');await capture('removed-reinsert-next');
 await focusCell(0,2);await capture('before-empty');await page.keyboard.press('e');await capture('empty-focused');await page.keyboard.press('Tab');await capture('empty-next');await page.keyboard.press('i');await capture('restored');await point(cell(1,2));await capture('restore-hover');

 await page.keyboard.press('i');await focusCell(1,2);await capture('reverse-before');await page.keyboard.press('r');await capture('reverse-replaced');await page.keyboard.press('Shift+Tab');let rev=await capture('replacement-reverse');check('replacement reverse is annual 2024',/2024/.test(rev.focus.label||rev.focus.text)&&/Year|for the year/.test(rev.focus.label||rev.focus.text),rev.focus);
 if(target==='candidate'){
  await page.keyboard.press('i');await focusCell(1,2);await capture('move-before');await page.keyboard.press('p');let moved=await capture('move-after');check('global key move preserves native March focus',moved.identity?.connected&&moved.identity?.sameFocused&&/2025 Mar/.test(moved.focus.label),moved);
  await page.keyboard.press('Tab');let next=await capture('move-next');check('Tab after move reaches April',/2025 Apr/.test(next.focus.label),next.focus);
  await page.keyboard.press('p');let back=await capture('move-back');check('move back retains April',/2025 Apr/.test(back.focus.label),back.focus);
  await page.keyboard.press('g');await capture('grid-remounted');await focusCell(1,2);await page.keyboard.press('r');await capture('remount-replaced');await page.keyboard.press('Shift+Tab');let prev=await capture('remount-reverse');check('remount reverse reaches annual 2024',/2024 Year/.test(prev.focus.label),prev.focus);
  await page.keyboard.press('i');await focusCell(1,2);await page.keyboard.press('r');await page.keyboard.press('Tab');let forward=await capture('remount-forward');check('remount forward reaches Jan 2030',/2030 Jan/.test(forward.focus.label),forward.focus);
 }
 } catch(e) {check('sequence completed',false,String(e));}
 await cdp.send('Page.stopScreencast');await Promise.all(pending);await Promise.all(reads);
 const inputs=await page.evaluate(()=>globalThis.__inputs);const synthetic=inputs.filter(e=>!e.isTrusted);check('trusted native inputs',synthetic.every(e=>e.type==='click'&&e.x===0&&e.y===0),synthetic);check('no page errors',!errors.length,errors);
 const concat=['ffconcat version 1.0'];frames.forEach((f,i)=>{concat.push(`file '${f.file}'`,'option framerate 1000000');if(i+1<frames.length)concat.push(`duration ${(frames[i+1].metadata.timestamp-f.metadata.timestamp).toFixed(6)}`)});await fs.writeFile(path.join(out,'frames.ffconcat'),concat.join('\n')+'\n');
 const enc=spawnSync('ffmpeg',['-nostdin','-v','warning','-f','concat','-safe','0','-i',path.join(out,'frames.ffconcat'),'-fps_mode','passthrough','-c:v','libx264','-preset','ultrafast','-crf','0','-pix_fmt','yuv444p','-video_track_timescale','1000000',path.join(out,'capture.mp4')],{encoding:'utf8'});await fs.writeFile(path.join(out,'ffmpeg.log'),enc.stderr);check('video encode',enc.status===0,enc.status);
 const report={target,reducedMotion,browser:browser.version(),viewport:{width:1000,height:800,dpr:1},scripts,frames,states,checks,inputs,errors};await fs.writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));reports.push({target,reducedMotion,pass:checks.every(x=>x.pass),checks:checks.length,failures:checks.filter(x=>!x.pass).map(x=>x.name)});console.log(reports.at(-1));await context.close();
}
}finally{await browser.close();}
await fs.writeFile(path.join(root,attempt,'summary.json'),JSON.stringify(reports,null,2));
