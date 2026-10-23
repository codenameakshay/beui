import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const out='/tmp/beui-mono-research-20261023';
const mode=process.argv[2]||'source';
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const results=[]; const sha=b=>createHash('sha256').update(b).digest('hex');
try {for(const chart of (mode==='source'?['candle','volume']:['candle','volume','probe','gallery-candle','gallery-volume'])) {
 const ctx=await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,colorScheme:'light',reducedMotion:'reduce'}); const p=await ctx.newPage(); const resources=[]; const pending=[]; const errors=[];
 p.on('pageerror',e=>errors.push(String(e))); p.on('response',r=>{if(/\.(js|wasm|ttf|woff2|json)(\?|$)/.test(r.url()))pending.push(r.body().then(async b=>{resources.push({url:r.url(),status:r.status(),bytes:b.length,sha256:sha(b)});}));});
 const url=`http://127.0.0.1:18148/${mode==='source'?'source':'candidate-exact'}/?chart=${chart}&theme=light&width=576${chart.startsWith('gallery')?'&slug='+ (chart==='gallery-candle'?'candlestick-chart':'volume-profile'):''}`;
 await p.goto(url,{waitUntil:'networkidle'}); if(mode!=='source')await p.waitForFunction(()=>typeof __readMono==='function'&&__readMono().length>0); await p.evaluate(()=>document.fonts.ready); await p.waitForTimeout(1500);
 await p.screenshot({path:`${out}/${mode}-${chart}.png`});
 let data;if(mode==='source') {
 data=await p.evaluate(()=>{let i=0;return [...document.querySelectorAll('main *')].filter(e=>e.childNodes.length&&[...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim())).map(e=>{const s=getComputedStyle(e);const range=document.createRange();range.selectNodeContents(e);const rect=range.getBoundingClientRect().toJSON();e.dataset.probeId=String(i++);return {id:e.dataset.probeId,text:e.textContent,rect,box:e.getBoundingClientRect().toJSON(),family:s.fontFamily,size:s.fontSize,weight:s.fontWeight,tracking:s.letterSpacing,lineHeight:s.lineHeight,features:s.fontFeatureSettings};});});
 const cdp=await ctx.newCDPSession(p);await cdp.send('DOM.enable');await cdp.send('CSS.enable');const doc=await cdp.send('DOM.getDocument');
 for(const row of data){const {nodeId}=await cdp.send('DOM.querySelector',{nodeId:doc.root.nodeId,selector:`[data-probe-id="${row.id}"]`});row.platform=await cdp.send('CSS.getPlatformFontsForNode',{nodeId});}
 // Zero-size inline baseline markers only after untouched screenshot and original bounds.
 const baselines=await p.evaluate(()=>[...document.querySelectorAll('[data-probe-id]')].map(e=>{const marker=document.createElement('span');marker.style.cssText='display:inline-block;width:0;height:0;padding:0;margin:0;vertical-align:baseline';e.append(marker);const y=marker.getBoundingClientRect().y;marker.remove();return {id:e.dataset.probeId,baseline:y};}));data.forEach(r=>r.baseline=baselines.find(b=>b.id===r.id).baseline);
 }else data=await p.evaluate(()=>__readMono());
 const env=await p.evaluate(()=>({dpr:devicePixelRatio,fonts:[...document.fonts].map(f=>({family:f.family,weight:f.weight,status:f.status})),ready:document.fonts.status,ua:navigator.userAgent}));
 await Promise.all(pending);results.push({chart,url,data,env,resources,errors});await writeFile(`${out}/${mode}-measurements.json`,JSON.stringify(results,null,2));await ctx.close(); console.log(mode,chart,data.length);
}}finally{await browser.close();}
