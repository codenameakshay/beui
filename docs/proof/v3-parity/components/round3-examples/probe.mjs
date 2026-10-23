import assert from 'node:assert/strict';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {examples} from './inventory.mjs';

export const playwright = process.env.PARITY_PLAYWRIGHT ?? '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
export const json = async path => JSON.parse(await readFile(path,'utf8'));
export const save = (path,value) => writeFile(path,JSON.stringify(value,null,2));
export const inspect = page => page.evaluate(() => {
  const rect = el => el.getBoundingClientRect().toJSON();
  return {
    url:location.href, reduce:matchMedia('(prefers-reduced-motion: reduce)').matches,
    active:document.activeElement ? {tag:document.activeElement.tagName,role:document.activeElement.getAttribute('role'),name:document.activeElement.getAttribute('aria-label') || document.activeElement.textContent} : null,
    probe:globalThis.__beuiCapture ?? null,
    stage:document.querySelector('#stage') ? rect(document.querySelector('#stage')) : null,
    controls:[...document.querySelectorAll('button,input,[role],flt-semantics,#stage,tr')].map(el => ({
      tag:el.tagName,role:el.getAttribute('role'),name:el.getAttribute('aria-label') || el.innerText || el.textContent,
      value:el.getAttribute('aria-valuetext') ?? el.getAttribute('aria-valuenow') ?? el.value,
      disabled:el.hasAttribute('disabled') || el.getAttribute('aria-disabled') === 'true',
      checked:el.getAttribute('aria-checked'),selected:el.getAttribute('aria-selected'),
      sort:el.getAttribute('aria-sort'),rect:rect(el),
    })).filter(el => el.rect.width > 0 && el.rect.height > 0),
  };
});

export async function open(browser,origin,item,theme,motion) {
  const context = await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,colorScheme:theme,reducedMotion:motion,locale:'en-US',timezoneId:'Asia/Kolkata'});
  const page = await context.newPage();
  page.setDefaultTimeout(5000);
  const scripts = [],reads = [];
  page.on('response', response => {
    if (/\.m?js(?:\?|$)/.test(response.url())) reads.push(response.body().then(bytes => scripts.push({url:response.url(),sha256:sha256(bytes),bytes:bytes.length,status:response.status()})));
  });
  const url = `http://127.0.0.1:18120/${origin}/?example=${item.key}&theme=${theme}&captureProbe=1`;
  await page.goto(url,{waitUntil:'domcontentloaded'});
  await page.evaluate(() => document.fonts.ready);
  if (origin !== 'source') {
    await page.waitForFunction(() => globalThis.__beuiCapture);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  } else {
    await page.waitForSelector('#stage');
  }
  await page.waitForTimeout(300);
  await Promise.all(reads);
  assert(scripts.length > 0);
  const environment = await inspect(page);
  assert.equal(environment.reduce,motion==='reduce');
  if (origin !== 'source') assert.equal(environment.probe.disableAnimations,motion==='reduce');
  return {context,page,scripts,environment,url};
}

if (process.argv[1] === import.meta.filename) {
  const [origin,batch,theme='light',motion='no-preference',...keys] = process.argv.slice(2);
  const {chromium} = await import(pathToFileURL(playwright));
  const browser = await chromium.launch({headless:true,executablePath:process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
  try {
    for (const item of examples.filter(item => !keys.length || keys.includes(item.key))) {
      const output = resolve(import.meta.dirname,batch,`${origin}-${theme}-${motion}-${item.key}`);
      await mkdir(output,{recursive:true});
      const {context,page,scripts,environment,url} = await open(browser,origin,item,theme,motion);
      await save(join(output,'scripts.json'),scripts);
      await save(join(output,'environment.json'),environment);
      await page.screenshot({path:join(output,'rest.png')});
      console.log(JSON.stringify({key:item.key,url,controls:environment.controls.filter(c=>c.role || c.tag==='BUTTON').map(c=>({name:c.name,value:c.value,rect:c.rect}))}));
      await context.close();
    }
  } finally {await browser.close();}
}
