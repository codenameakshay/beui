import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const root=path.dirname(new URL(import.meta.url).pathname);
const attempt=process.argv[2]||'attempt-1';
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
 await page.goto('http://127.0.0.1:18146/'+(target==='source'?'source/':'candidate/example/build/web/'));
 await page.waitForFunction(()=>globalThis.__fixture?.snapshot);
 await page.locator('flt-semantics-placeholder').evaluateAll(ns=>ns.forEach(n=>n.click()));
 await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(700);await page.mouse.move(10,10);
 const cdp=await context.newCDPSession(page);const frames=[],pending=[];
 cdp.on('Page.screencastFrame',e=>{const file=`original-frames/frame_${String(frames.length).padStart(6,'0')}.png`;const bytes=Buffer.from(e.data,'base64');frames.push({file,sha256:hash(bytes),metadata:e.metadata});pending.push(fs.writeFile(path.join(out,file),bytes),cdp.send('Page.screencastFrameAck',{sessionId:e.sessionId}));});
 await cdp.send('Page.startScreencast',{format:'png',everyNthFrame:1});
 const states=[],checks=[];
 const check=(name,ok,actual)=>{checks.push({name,pass:!!ok,actual});if(!ok)console.log('FAIL',target,reducedMotion,name,JSON.stringify(actual));};
 const capture=async(name,expected)=>{await page.waitForTimeout(450);const aria=await page.locator('body').ariaSnapshot();const observed=await page.evaluate(()=>({fixture:globalThis.__fixture,inputs:globalThis.__inputs,reduce:matchMedia('(prefers-reduced-motion: reduce)').matches,hover:matchMedia('(hover: hover) and (pointer: fine)').matches,focus:{tag:document.activeElement?.tagName,text:document.activeElement?.textContent,label:document.activeElement?.getAttribute('aria-label')}}));const png=Buffer.from((await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false})).data,'base64');await fs.writeFile(path.join(out,name+'.png'),png);const s={name,aria,...observed,screenshot:{file:name+'.png',sha256:hash(png)}};states.push(s);if(expected)for(const text of expected)check(name+': '+text,aria.includes(text),aria);return s;};
 const price=p=>page.getByRole('button',{name:p.toFixed(2),exact:true});
 const move=async p=>{const r=await price(p).boundingBox();if(!r)throw Error('missing price '+p);await page.mouse.move(r.x+r.width/2,r.y+r.height/2)};
 const click=async p=>{const r=await price(p).boundingBox();await page.mouse.click(r.x+r.width/2,r.y+r.height/2)};
 const control=async label=>{const r=await page.getByRole('button',{name:label,exact:true}).boundingBox();await page.mouse.click(r.x+r.width/2,r.y+r.height/2);await page.mouse.move(10,10)};
 const empty=['Hover a level'];
 try {
 let s=await capture('rest',empty);check('motion',s.reduce===(reducedMotion==='reduce')&&s.fixture.disableAnimations===s.reduce,s.fixture);check('paused',s.fixture.paused&&s.fixture.state==='initial',s.fixture);
 await page.waitForTimeout(1100);s=await capture('paused-hold',empty);check('paused hold',s.fixture.state==='initial',s.fixture);
 for(const [name,p,qty,quote,avg] of [['ask-a',101,4,'404.00','101.00'],['ask-b',102,10,'1,016.00','101.60'],['bid-a',99,2,'198.00','99.00'],['bid-b',98,5,'492.00','98.40']]) {
  await move(p);await capture('hover-'+name,[`${qty} BTC · ${quote} USD`,'Avg',avg]);await click(p);s=await capture('select-'+name,[`${qty} BTC · ${quote} USD`]);const selected=s.fixture.selections.at(-1);check('select callback '+name,selected?.price===p&&selected?.total===qty,selected);await page.mouse.move(10,10);await capture('exit-'+name,empty);
 }
 await click(102);await page.mouse.move(10,10);await page.keyboard.press('Tab');await capture('tab-ask-a',['4 BTC · 404.00 USD']);await page.keyboard.press('Enter');s=await capture('enter-ask-a',['4 BTC · 404.00 USD']);check('keyboard selection',s.fixture.selections.at(-1)?.price===101,s.fixture.selections.at(-1));
 await page.keyboard.press('Tab');await capture('tab-bid-a',['2 BTC · 198.00 USD']);await page.keyboard.press('Tab');await capture('tab-bid-b',['5 BTC · 492.00 USD']);await page.keyboard.press('Shift+Tab');await capture('reverse-bid-a',['2 BTC · 198.00 USD']);
 await page.keyboard.press('Home');await page.keyboard.press('ArrowRight');await capture('ignored-chart-arrows',['2 BTC · 198.00 USD']);
 await page.keyboard.press('r');s=await capture('reorder-focused',['2 BTC · 198.00 USD']);check('reorder state',s.fixture.state==='reorder',s.fixture.state);
 await page.keyboard.press('s');s=await capture('step-focused',['3 BTC · 297.00 USD']);check('step state',s.fixture.state==='step',s.fixture.state);
 await control('initial');await move(102);await capture('restore-hover',['10 BTC · 1,016.00 USD']);
 await control('empty');s=await capture('empty',['No asks','No bids','Spread unavailable',...empty]);check('empty snapshot',s.fixture.snapshot.bids.length===0&&s.fixture.snapshot.asks.length===0,s.fixture);
 await control('bids');await capture('bids-only',['No asks','Spread unavailable',...empty]);await move(98);await capture('bids-only-hover',['5 BTC · 492.00 USD']);
 await control('asks');await capture('asks-only',['No bids','Spread unavailable',...empty]);await move(102);await capture('asks-only-hover',['10 BTC · 1,016.00 USD']);
 await control('initial');await capture('restored',empty);
 } catch(e) {check('sequence completed',false,String(e));}
 await cdp.send('Page.stopScreencast');await Promise.all(pending);await Promise.all(reads);
 const inputs=await page.evaluate(()=>globalThis.__inputs);const synthetic=inputs.filter(e=>!e.isTrusted);check('trusted native inputs',synthetic.every(e=>e.type==='click'&&e.x===0&&e.y===0),synthetic);check('no page errors',!errors.length,errors);
 const concat=['ffconcat version 1.0'];frames.forEach((f,i)=>{concat.push(`file '${f.file}'`,'option framerate 1000000');if(i+1<frames.length)concat.push(`duration ${(frames[i+1].metadata.timestamp-f.metadata.timestamp).toFixed(6)}`)});await fs.writeFile(path.join(out,'frames.ffconcat'),concat.join('\n')+'\n');
 const enc=spawnSync('ffmpeg',['-nostdin','-v','warning','-f','concat','-safe','0','-i',path.join(out,'frames.ffconcat'),'-fps_mode','passthrough','-c:v','libx264','-preset','ultrafast','-crf','0','-pix_fmt','yuv444p','-video_track_timescale','1000000',path.join(out,'capture.mp4')],{encoding:'utf8'});await fs.writeFile(path.join(out,'ffmpeg.log'),enc.stderr);check('video encode',enc.status===0,enc.status);
 const report={target,reducedMotion,browser:browser.version(),viewport:{width:1000,height:800,dpr:1},scripts,frames,states,checks,inputs,errors};await fs.writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));reports.push({target,reducedMotion,pass:checks.every(x=>x.pass),checks:checks.length,failures:checks.filter(x=>!x.pass).map(x=>x.name)});console.log(reports.at(-1));await context.close();
}
}finally{await browser.close();}
await fs.writeFile(path.join(root,attempt,'summary.json'),JSON.stringify(reports,null,2));
