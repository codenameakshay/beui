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
 await page.goto('http://127.0.0.1:18153/'+(target==='source'?'source/':'candidate/example/build/web/'));
 await page.waitForFunction(()=>globalThis.__fixture?.snapshot);
 await page.locator('flt-semantics-placeholder').evaluateAll(ns=>ns.forEach(n=>n.click()));
 await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(700);await page.mouse.move(10,10);
 const cdp=await context.newCDPSession(page);const frames=[],pending=[];
 cdp.on('Page.screencastFrame',e=>{const file=`original-frames/frame_${String(frames.length).padStart(6,'0')}.png`;const bytes=Buffer.from(e.data,'base64');frames.push({file,sha256:hash(bytes),metadata:e.metadata});pending.push(fs.writeFile(path.join(out,file),bytes),cdp.send('Page.screencastFrameAck',{sessionId:e.sessionId}));});
 await cdp.send('Page.startScreencast',{format:'png',everyNthFrame:1});
 const states=[],checks=[];
 const check=(name,ok,actual)=>{checks.push({name,pass:!!ok,actual});if(!ok)console.log('FAIL',target,reducedMotion,name,JSON.stringify(actual));};
 const capture=async(name,expected)=>{await page.waitForTimeout(450);const aria=await page.locator('body').ariaSnapshot();const observed=await page.evaluate(()=>({buttons:[...document.querySelectorAll('[role=button],button')].map(n=>({label:n.getAttribute('aria-label'),text:n.textContent,pressed:n.getAttribute('aria-pressed'),selected:n.getAttribute('aria-selected'),opacity:getComputedStyle(n.parentElement).opacity})),fixture:globalThis.__fixture,inputs:globalThis.__inputs,reduce:matchMedia('(prefers-reduced-motion: reduce)').matches,hover:matchMedia('(hover: hover) and (pointer: fine)').matches,focus:{tag:document.activeElement?.tagName,text:document.activeElement?.textContent,label:document.activeElement?.getAttribute('aria-label')}}));const png=Buffer.from((await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false})).data,'base64');await fs.writeFile(path.join(out,name+'.png'),png);const s={name,aria,...observed,screenshot:{file:name+'.png',sha256:hash(png)}};states.push(s);if(expected)for(const text of expected)check(name+': '+text,aria.includes(text),aria);return s;};
 const cell=(w,d)=>target==='source'?page.locator(`[data-heat-cell="${w}-${d}"]`):page.getByRole('button',{name:new RegExp(' commits on '+new Date(Date.UTC(2026,8,28+w*7+d)).toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric',timeZone:'UTC'}).replaceAll(',',',')+'(?:$| )')});
 const point=async(locator,click=false)=>{const r=await locator.boundingBox();if(!r)throw Error('missing bounds');if(click)await page.mouse.click(r.x+r.width/2,r.y+r.height/2);else await page.mouse.move(r.x+r.width/2,r.y+r.height/2);await page.waitForTimeout(250)};
 const legend=i=>page.getByRole('button',{name:(target==='source'?'Show':'Filter')+' activity level '+i,exact:true});
 try {
 let s=await capture('rest');check('motion',s.reduce===(reducedMotion==='reduce')&&s.fixture.disableAnimations===s.reduce,s.fixture);
 await point(cell(0,0));await capture('hover-zero');await page.mouse.move(10,10);await capture('hover-exit');
 await point(cell(0,0),true);await page.mouse.move(10,10);await page.keyboard.press('Escape');await page.keyboard.press('Tab');await capture('tab-tuesday');
 await page.keyboard.press('b');await capture('blank-focused');await page.keyboard.press('Tab');await capture('blank-tab');
 await page.keyboard.press('r');await capture('refresh-focused');await page.keyboard.press('Shift+Tab');await capture('refresh-reverse');
 await page.keyboard.press('i');await page.keyboard.press('Escape');await point(legend(2));await capture('filter-hover');await page.mouse.move(10,10);await capture('filter-hover-exit');
 await point(legend(2),true);await page.mouse.move(10,10);await capture('filter-click-exit');
 await page.mouse.move(10,10);await page.keyboard.press('Escape');await page.waitForTimeout(500);await point(cell(3,4),true);await page.mouse.move(10,10);await page.keyboard.press('Escape');await capture('before-last-day-tab');await page.keyboard.press('Tab');await capture('last-day-tab');await page.keyboard.press('Tab');await capture('legend-next-tab');
 await page.mouse.move(10,10);await page.keyboard.press('Escape');await page.waitForTimeout(500);await point(cell(3,4),true);await page.mouse.move(10,10);await page.keyboard.press('Escape');await capture('before-future-removal');await page.keyboard.press('d');await capture('future-removal-focused');await page.keyboard.press('Tab');await capture('future-removal-next');
 await page.keyboard.press('i');await page.waitForTimeout(500);await point(cell(3,3),true);await page.mouse.move(10,10);await page.keyboard.press('Escape');await capture('before-shrink');await page.keyboard.press('s');await capture('shrink-focused');await page.keyboard.press('Tab');await capture('shrink-next');

 await page.keyboard.press('i');await page.waitForTimeout(400);await point(cell(3,4),true);await page.mouse.move(10,10);await page.keyboard.press('Escape');await page.keyboard.press('d');await capture('reverse-removed');await page.keyboard.press('Shift+Tab');await capture('reverse-next');
 await page.keyboard.press('i');await page.waitForTimeout(400);await point(cell(3,4),true);await page.mouse.move(10,10);await page.keyboard.press('Escape');await page.keyboard.press('d');await capture('external-removed');await point(page.getByRole('button',{name:'date',exact:true}),true);await page.mouse.move(10,10);await capture('external-focused');await page.keyboard.press('Shift+Tab');await capture('external-reverse');
 await page.keyboard.press('i');await page.waitForTimeout(400);await point(cell(0,0),true);await point(cell(3,4),true);await page.mouse.move(10,10);await capture('locked');await page.keyboard.press('d');await capture('locked-removed');await point(cell(1,0),true);await page.mouse.move(10,10);await capture('new-anchor');await point(cell(1,1),true);await page.mouse.move(10,10);await capture('new-anchor-locked');
 await page.keyboard.press('i');await capture('restore');
 } catch(e) {check('sequence completed',false,String(e));}
 await cdp.send('Page.stopScreencast');await Promise.all(pending);await Promise.all(reads);
 const inputs=await page.evaluate(()=>globalThis.__inputs);const synthetic=inputs.filter(e=>!e.isTrusted);check('trusted native inputs',synthetic.every(e=>e.type==='click'&&e.x===0&&e.y===0),synthetic);check('no page errors',!errors.length,errors);
 const concat=['ffconcat version 1.0'];frames.forEach((f,i)=>{concat.push(`file '${f.file}'`,'option framerate 1000000');if(i+1<frames.length)concat.push(`duration ${(frames[i+1].metadata.timestamp-f.metadata.timestamp).toFixed(6)}`)});await fs.writeFile(path.join(out,'frames.ffconcat'),concat.join('\n')+'\n');
 const enc=spawnSync('ffmpeg',['-nostdin','-v','warning','-f','concat','-safe','0','-i',path.join(out,'frames.ffconcat'),'-fps_mode','passthrough','-c:v','libx264','-preset','ultrafast','-crf','0','-pix_fmt','yuv444p','-video_track_timescale','1000000',path.join(out,'capture.mp4')],{encoding:'utf8'});await fs.writeFile(path.join(out,'ffmpeg.log'),enc.stderr);check('video encode',enc.status===0,enc.status);
 const report={target,reducedMotion,browser:browser.version(),viewport:{width:1000,height:800,dpr:1},scripts,frames,states,checks,inputs,errors};await fs.writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));reports.push({target,reducedMotion,pass:checks.every(x=>x.pass),checks:checks.length,failures:checks.filter(x=>!x.pass).map(x=>x.name)});console.log(reports.at(-1));await context.close();
}
}finally{await browser.close();}
await fs.writeFile(path.join(root,attempt,'summary.json'),JSON.stringify(reports,null,2));
