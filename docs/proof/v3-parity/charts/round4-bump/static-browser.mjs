import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const side = process.argv[2];
const run = process.argv[3] ?? 'v1';
const root = `docs/proof/v3-parity/charts/round4-bump/static-${side}-${run}`;
await mkdir(root);
const browser = await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const results = [];
try {
  for (const theme of ['dark','light']) for (const variant of ['default','composed','narrow','empty','missing','update']) {
    const page = await browser.newPage({viewport:{width:variant === 'narrow' ? 390 : 800,height:600},colorScheme:theme,reducedMotion:'reduce'});
    const scripts = [];
    const reads = [];
    page.on('response', response => {if (/\.(?:js|css|woff2|ttf)(?:\?|$)/.test(response.url())) reads.push(response.body().then(bytes => scripts.push({url:response.url(),bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')})));});
    const errors=[];page.on('pageerror',e=>errors.push(String(e)));
    await page.goto(`http://127.0.0.1:18115/${side}/?theme=${theme}&variant=${variant}`,{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(3000);
    await page.evaluate(()=>document.fonts.ready);
    await page.mouse.move(10,10);
    if (variant === 'update') {await page.keyboard.press('u');await page.waitForTimeout(800);}
    await page.screenshot({path:`${root}/${theme}-${variant}.png`});
    const environment = await page.evaluate(() => ({viewport:{width:innerWidth,height:innerHeight},browserReducedMotion:matchMedia('(prefers-reduced-motion: reduce)').matches,flutterCapture:globalThis.__beuiCapture ?? null,fonts:[...document.fonts].map(x=>({family:x.family,status:x.status,weight:x.weight})),stage:document.querySelector('main')?.getBoundingClientRect().toJSON(),sourceLegend:[...document.querySelectorAll('button[aria-label^="Highlight"]')].map(x=>({text:x.textContent,rect:x.getBoundingClientRect().toJSON(),pressed:x.getAttribute('aria-pressed')}))}));
    assert.equal(environment.browserReducedMotion,true);
    if (side !== 'source') assert.equal(environment.flutterCapture.disableAnimations,true);
    await Promise.all(reads);
    results.push({side,theme,variant,environment,scripts,errors});
    await page.close();
  }
} finally {
  await writeFile(`${root}/observations.json`,JSON.stringify(results,null,2),{flag:'wx'});
  await browser.close();
}
