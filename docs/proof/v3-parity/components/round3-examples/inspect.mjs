import {mkdir, writeFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';

const {chromium} = await import(pathToFileURL(process.env.PARITY_PLAYWRIGHT ?? '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs'));
const output = resolve(process.argv[2]);
await mkdir(output);
const browser = await chromium.launch({headless:true,executablePath:process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const observations = [];
try {
  for (const origin of ['source','before']) {
    const page = await browser.newPage({viewport:{width:1280,height:1000},colorScheme:'light',reducedMotion:'no-preference'});
    const scripts = [];
    const reads = [];
    page.on('response', response => {
      if (/\.js(?:\?|$)/.test(response.url())) reads.push(response.body().then(bytes => scripts.push({url:response.url(),sha256:createHash('sha256').update(bytes).digest('hex')})));
    });
    await page.goto(`http://127.0.0.1:18120/${origin}/?slug=button&example=stateful&theme=light&color=Blue&previewWidth=592&captureProbe=1`);
    await page.waitForTimeout(origin === 'source' ? 700 : 2500);
    if (origin !== 'source') await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(300);
    await Promise.all(reads);
    const environment = await page.evaluate(() => ({reduce:matchMedia('(prefers-reduced-motion: reduce)').matches,probe:globalThis.__beuiCapture ?? null}));
    const controls = await page.locator('button,flt-semantics[role="button"]').evaluateAll(elements => elements.map(el => ({text:el.getAttribute('aria-label') || el.textContent,rect:el.getBoundingClientRect().toJSON()})));
    const submit = page.getByRole('button',{name:'Submit',exact:true});
    await submit.scrollIntoViewIfNeeded();
    await page.screenshot({path:join(output,`${origin}-rest.png`)});
    await submit.click();
    await page.waitForTimeout(350);
    const loading = await page.locator('button,flt-semantics[role="button"]').evaluateAll(elements => elements.map(el => ({text:el.getAttribute('aria-label') || el.textContent,disabled:el.hasAttribute('disabled') || el.getAttribute('aria-disabled')})));
    await page.screenshot({path:join(output,`${origin}-submit-350ms.png`)});
    await page.waitForTimeout(1350);
    const result = await page.locator('button,flt-semantics[role="button"]').evaluateAll(elements => elements.map(el => ({text:el.getAttribute('aria-label') || el.textContent,disabled:el.hasAttribute('disabled') || el.getAttribute('aria-disabled')})));
    await page.screenshot({path:join(output,`${origin}-submit-1700ms.png`)});
    observations.push({origin,scripts,environment,controls,loading,result});
    await writeFile(join(output,'observations.json'),JSON.stringify(observations,null,2));
    console.log(JSON.stringify({origin,loading,result}));
    await page.close();
  }
} finally {await browser.close();}
