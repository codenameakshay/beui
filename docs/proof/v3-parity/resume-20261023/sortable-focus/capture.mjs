import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';import {spawnSync} from 'node:child_process';
const root=path.dirname(new URL(import.meta.url).pathname),attempt=process.argv[2]||'attempt-1';await fs.mkdir(path.join(root,attempt));
const hash=b=>createHash('sha256').update(b).digest('hex');
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});const summary=[];
try {for(const target of ['source','candidate'])for(const reducedMotion of ['no-preference','reduce']){
 const out=path.join(root,attempt,`${target}-${reducedMotion}`);await fs.mkdir(path.join(out,'original-frames'),{recursive:true});
 const context=await browser.newContext({viewport:{width:1000,height:800},deviceScaleFactor:1,reducedMotion,colorScheme:'light'});const page=await context.newPage();const scripts=[],reads=[],errors=[],inputs=[],states=[],checks=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('response',r=>{if(r.status()===200&&/\.js(?:\?|$)/.test(r.url()))reads.push(r.body().then(async bytes=>{const sha256=hash(bytes);await fs.mkdir(path.join(root,'served-js'),{recursive:true});await fs.writeFile(path.join(root,'served-js',sha256+'.js'),bytes);scripts.push({url:r.url(),sha256,bytes:bytes.length})}));});
 await page.addInitScript(()=>{globalThis.__inputs=[];globalThis.__flutterTrace=[];globalThis.__focusChanged=(state)=>globalThis.__flutterTrace.push({time:performance.now(),...state});globalThis.__domTrace=[];let lastFocused;document.addEventListener('focusin',e=>{lastFocused=e.target},true);new MutationObserver(records=>{for(const r of records){if(r.type==='childList' && lastFocused && [...r.removedNodes,...r.addedNodes].some(n=>n===lastFocused||n.contains?.(lastFocused)))globalThis.__domTrace.push({time:performance.now(),parent:r.target.id,removed:[...r.removedNodes].map(n=>n.id),added:[...r.addedNodes].map(n=>n.id),focusedId:lastFocused.id,connected:lastFocused.isConnected,active:document.activeElement?.tagName,flutter:globalThis.__flutterFocus?.()});}}).observe(document,{subtree:true,childList:true});for(const type of ['keydown','keyup','pointerdown','pointerup','click','focusin','focusout'])document.addEventListener(type,e=>globalThis.__inputs.push({type,key:e.key,isTrusted:e.isTrusted,time:performance.now(),tag:e.target.tagName,label:e.target.getAttribute?.('aria-label'),text:e.target.textContent?.slice(0,60)}),true)});
 const cdp=await context.newCDPSession(page),frames=[],pending=[];
 cdp.on('Page.screencastFrame',e=>{const file=`original-frames/frame_${String(frames.length).padStart(6,'0')}.png`,bytes=Buffer.from(e.data,'base64');frames.push({file,sha256:hash(bytes),metadata:e.metadata});pending.push(fs.writeFile(path.join(out,file),bytes),cdp.send('Page.screencastFrameAck',{sessionId:e.sessionId}));});await cdp.send('Page.startScreencast',{format:'png',everyNthFrame:1});
 const check=(name,ok,actual)=>{checks.push({name,pass:!!ok,actual});if(!ok)console.log('FAIL',target,reducedMotion,name,JSON.stringify(actual));};
 const focus=()=>page.evaluate(()=>({tag:document.activeElement?.tagName,label:document.activeElement?.getAttribute('aria-label'),text:document.activeElement?.tagName==='BODY'?'':document.activeElement?.textContent?.slice(0,60)}));
 const capture=async(name,order,count,undo,focused)=>{
  await page.waitForTimeout(300);const aria=await page.locator('body').ariaSnapshot();const observed=await page.evaluate(()=>{const handles=[...document.querySelectorAll('[aria-label^="Reorder "]')].sort((a,b)=>a.getBoundingClientRect().y-b.getBoundingClientRect().y);const u=[...document.querySelectorAll('button,[role=button]')].find(n=>n.textContent.trim()==='Undo reorder');return {fixture:globalThis.__fixture,order:handles.map(n=>n.getAttribute('aria-label').replace('Reorder ','')),undo:!!u&&!u.disabled&&u.getAttribute('aria-disabled')!=='true',live:[...document.querySelectorAll('[aria-live],[role=status]')].map(n=>({text:n.textContent,label:n.getAttribute('aria-label')})),reduce:matchMedia('(prefers-reduced-motion: reduce)').matches}});
  const png=Buffer.from((await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false})).data,'base64');await fs.writeFile(path.join(out,name+'.png'),png);const s={name,aria,...observed,flutterFocus:await page.evaluate(()=>globalThis.__flutterFocus?.()),flutterTrace:await page.evaluate(()=>globalThis.__flutterTrace),domTrace:await page.evaluate(()=>globalThis.__domTrace),focus:await focus(),screenshot:{file:name+'.png',sha256:hash(png)}};states.push(s);
  check(name+' order',JSON.stringify(s.order)===JSON.stringify(order),s.order);check(name+' callbacks',s.fixture.calls.length===count,s.fixture.calls);check(name+' Undo',s.undo===undo,s.undo);if(focused)check(name+' focus',s.focus.label===`Reorder ${focused}`||s.focus.text===`Reorder ${focused}`,s.focus);return s;
 };
 const tabToA=async()=>{for(let i=0;i<14;i++){const f=await focus();if(f.label==='Reorder A'||f.text==='Reorder A')return;await page.keyboard.press('Tab');await page.waitForTimeout(500);}throw Error('Tab did not reach A');};
 const key=async(k)=>{await page.keyboard.press(k);await page.waitForTimeout(500)};
 const undoClick=async()=>{const r=await page.getByRole('button',{name:'Undo reorder',exact:true}).boundingBox();if(!r)throw Error('Undo bounds missing');await page.mouse.click(r.x+r.width/2,r.y+r.height/2);await page.mouse.move(5,5)};
 try{for(const scenario of ['reject','accept','reset','membership','uncontrolled','disabled']){
  const mode=['reset','membership'].includes(scenario)?'accept':scenario;
  await page.goto(`http://127.0.0.1:${target==='source'?18165:18166}/?mode=${mode}`);await page.waitForFunction(()=>globalThis.__fixture);await page.waitForTimeout(1500);await page.mouse.move(5,5);
  let s=await capture(scenario+'-rest',['A','B','C'],0,false);check(scenario+' motion',s.reduce===(reducedMotion==='reduce')&&s.fixture.reduce===s.reduce,s.fixture.reduce);
  if(scenario==='disabled'){
   await key('Tab');await key('ArrowDown');await key('Home');await key('End');await undoClick();s=await capture('disabled-inputs',['A','B','C'],0,false);check('disabled focus excludes handles',!/^Reorder [ABCD]$/.test(s.focus.label||s.focus.text),s.focus);
  }else{
   await key('Tab');await tabToA();await capture(scenario+'-focused',['A','B','C'],0,false,'A');
   await key('Home');await key('ArrowUp');await capture(scenario+'-boundary',['A','B','C'],0,false,'A');
   await key('ArrowDown');s=await capture(scenario+'-move',scenario==='reject'?['A','B','C']:['B','A','C'],1,scenario!=='reject','A');
   check(scenario+' proposal payload',JSON.stringify(s.fixture.calls[0])==='["B","A","C"]',s.fixture.calls);
   if(scenario==='reject'){
    await undoClick();s=await capture('reject-undo-attempt',['A','B','C'],1,false);check('reject no restoration DOM announcement',!s.aria.includes('Previous order restored.'),s.aria);
   }else if(scenario==='reset'){
    await tabToA();await key('r');await capture('external-reset',['A','B','C'],1,false);await undoClick();await capture('reset-undo-attempt',['A','B','C'],1,false);
   }else if(scenario==='membership'){
    await tabToA();await key('m');await capture('membership-replaced',['B','A','D'],1,false);await tabToA();await key('i');await capture('membership-reintroduced',['B','A','C'],1,false);await undoClick();await capture('membership-undo-attempt',['B','A','C'],1,false);
   }else{
    await undoClick();s=await capture(scenario+'-undo',['A','B','C'],2,false,'A');check(scenario+' restoration DOM observation',s.aria.includes('Previous order restored.'),s.aria);
    await tabToA();await key('End');await capture(scenario+'-end',['B','C','A'],3,true,'A');
    // Explicit native Tab recovery allows boundary checks even if the move lost DOM focus.
    await tabToA();await key('End');await key('ArrowDown');await capture(scenario+'-last-boundary',['B','C','A'],3,true,'A');
    await key('Home');await capture(scenario+'-home',['A','B','C'],4,true,'A');
    await undoClick();await capture(scenario+'-home-undo',['B','C','A'],5,false,'B');
   }
  }
  inputs.push({scenario,events:await page.evaluate(()=>globalThis.__inputs)});
 }}catch(e){check('sequence completed',false,String(e));}
 await cdp.send('Page.stopScreencast');await Promise.all(pending);await Promise.all(reads);check('trusted input only',inputs.every(s=>s.events.every(e=>e.isTrusted)),inputs.flatMap(s=>s.events).filter(e=>!e.isTrusted));check('no page errors',!errors.length,errors);
 const concat=['ffconcat version 1.0'];frames.forEach((f,i)=>{concat.push(`file '${f.file}'`,'option framerate 1000000');if(i+1<frames.length)concat.push(`duration ${(frames[i+1].metadata.timestamp-f.metadata.timestamp).toFixed(6)}`)});await fs.writeFile(path.join(out,'frames.ffconcat'),concat.join('\n')+'\n');
 const enc=spawnSync('ffmpeg',['-nostdin','-v','warning','-f','concat','-safe','0','-i',path.join(out,'frames.ffconcat'),'-fps_mode','passthrough','-c:v','libx264','-preset','ultrafast','-crf','0','-pix_fmt','yuv444p','-video_track_timescale','1000000',path.join(out,'capture.mp4')],{encoding:'utf8'});await fs.writeFile(path.join(out,'ffmpeg.log'),enc.stderr);check('video encode',enc.status===0,enc.status);
 const probe=spawnSync('ffprobe',['-v','error','-count_frames','-show_entries','stream=nb_read_frames,codec_name,width,height','-of','json',path.join(out,'capture.mp4')],{encoding:'utf8'});await fs.writeFile(path.join(out,'ffprobe.json'),probe.stdout);const decoded=Number(JSON.parse(probe.stdout).streams[0].nb_read_frames);check('decoded frame count',decoded===frames.length,{decoded,original:frames.length});
 const report={target,reducedMotion,browser:browser.version(),viewport:{width:1000,height:800,dpr:1},scripts,frames,states,checks,inputs,errors};await fs.writeFile(path.join(out,'results.json'),JSON.stringify(report,null,2));summary.push({target,reducedMotion,states:states.length,frames:frames.length,decoded,checks:checks.length,failures:checks.filter(x=>!x.pass).map(x=>x.name)});console.log(summary.at(-1));await context.close();
}}finally{await browser.close()}await fs.writeFile(path.join(root,attempt,'summary.json'),JSON.stringify(summary,null,2));
