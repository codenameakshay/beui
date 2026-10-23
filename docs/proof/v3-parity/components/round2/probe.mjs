import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = import.meta.dirname;
const output = join(root, process.argv[2] ?? 'measurements-1');
await mkdir(output);
const inventory = JSON.parse(await readFile(join(root, '../inventory.json')));
const slugs = process.argv.slice(3);
const routes = inventory.routes.filter(route => !slugs.length || slugs.includes(route.id.split('/')[1]));
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const diskHash = sha256(await readFile('example/build/round2-dc564bd7/main.dart.js'));
const servedHash = sha256(Buffer.from(await (await fetch('http://127.0.0.1:8110/main.dart.js')).arrayBuffer()));
if (diskHash !== servedHash) throw Error('Served JavaScript differs from frozen build');
const browser = await chromium.launch({headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const results = [];
try {
  for (const route of routes) {
    const slug = route.id.split('/')[1];
    const result = {slug, sourceUrl: route.sourceUrl, diskHash, servedHash};
    for (const origin of ['reference', 'candidate']) {
      const page = await browser.newPage({viewport: {width:1280,height:1000}, colorScheme:'light', reducedMotion:'no-preference'});
      const url = origin === 'reference' ? route.sourceUrl : `http://127.0.0.1:8110/?slug=${slug}&theme=light&color=Blue&previewWidth=592&captureProbe=1`;
      try {
        await page.goto(url, {waitUntil:'domcontentloaded'});
        if (origin === 'reference') await page.getByRole('tab', {name:'Light theme', exact:true}).click();
        await page.waitForTimeout(origin === 'reference' ? 1000 : 3000);
        if (origin === 'candidate') {
          await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
          await page.waitForTimeout(250);
        }
        result[origin] = await page.evaluate(origin => {
          const stage = origin === 'reference' ? [...document.querySelectorAll('main div')].find(el => el.className.includes('min-h-[') && el.className.includes('justify-center')) : null;
          const bounds = el => el.getBoundingClientRect().toJSON();
          const elements = origin === 'reference' ? [...(stage?.querySelectorAll('button,input,[role="radio"],[role="option"],[role="slider"],a') ?? [])] : [...document.querySelectorAll('flt-semantics[role],input')];
          return {url:location.href, stage:stage ? bounds(stage) : null, probe:globalThis.__beuiCapture,
            controls:elements.map(el => ({tag:el.tagName,role:el.getAttribute('role'),name:el.getAttribute('aria-label') || el.textContent?.trim(),disabled:el.hasAttribute('disabled') || el.getAttribute('aria-disabled') === 'true',...bounds(el)})).filter(el=>el.width>3 && el.height>3),
            body:document.body.innerText.slice(-2000), htmlClass:document.documentElement.className};
        }, origin);
        await page.screenshot({path:join(output,`${slug}-${origin}.png`)});
      } catch (error) { result[origin] = {error:String(error)}; }
      await page.close();
    }
    results.push(result);
    await writeFile(join(output,'measurements.json'),JSON.stringify(results,null,2));
    console.log(JSON.stringify({slug,reference:result.reference.controls?.map(c=>c.name),candidate:result.candidate.controls?.map(c=>c.name),error:result.reference.error || result.candidate.error}));
  }
} finally { await browser.close(); }
