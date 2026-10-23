import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
const root='/tmp/beui-parent-icon-diagnostic';
const report={responses:[],errors:[],console:[]}; const pending=[];
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
try {
 const page=await browser.newPage({viewport:{width:1280,height:1000},deviceScaleFactor:1});
 page.on('pageerror',e=>report.errors.push(String(e)));
 page.on('console',m=>report.console.push(m.text()));
 page.on('response',r=>{if(/\.ttf|main.dart.js|FontManifest/.test(r.url())) pending.push(r.body().then(b=>report.responses.push({url:r.url(),status:r.status(),bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')})));});
 await page.goto('http://127.0.0.1:8110/?slug=alert&theme=light&color=Blue&previewWidth=592&captureProbe=1');
 await page.waitForFunction(()=>!!globalThis.__beuiCapture);
 await page.waitForTimeout(3500);
 await page.screenshot({path:root+'/before-semantics.png'});
 await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 await page.getByRole('button',{name:'Success',exact:true}).click();
 await page.waitForTimeout(1200);
 await page.screenshot({path:root+'/success.png'});
 await Promise.all(pending);
} finally {await writeFile(root+'/report.json',JSON.stringify(report,null,2));await browser.close();}
