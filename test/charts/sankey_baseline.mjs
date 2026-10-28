import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir, writeFile, readFile, copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {dirname} from 'node:path';
const output = 'docs/proof/v3-parity/charts/sankey/before-mounted';
await mkdir(dirname(output), {recursive:true});
await mkdir(output);
const browser = await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless:true});
try {
  const page = await browser.newPage({viewport:{width:1280,height:800}});
  await page.goto('http://127.0.0.1:18119/before/?slug=sankey-chart&section=charts');
  await page.waitForSelector('flutter-view', {timeout:60000});
  await page.waitForTimeout(3000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1000);
  const text = await page.locator('body').innerText();
  if (!text.includes('Treemap') || text.includes('Sankey Chart')) throw Error(`Unexpected fallback: ${text}`);
  await page.screenshot({path:`${output}/absent-route.png`});
  const hash = createHash('sha256').update(await readFile('/tmp/beui-sankey-20261023/before/main.dart.js')).digest('hex');
  await writeFile(`${output}/route.json`, JSON.stringify({revision:'8a1970d3', url:page.url(), viewport:{width:1280,height:800}, servedJsSha256:hash, renderedText:text, catalogHasSankey:false, result:'Unknown slug falls back to Charts index. No pristine Sankey widget baseline exists.'}, null,2));
} finally {await browser.close();}
const root = '/tmp/beui-charts-reference-20261023';
const files = ['lib/registry.ts','components/charts/sankey-chart.tsx','components/charts/sankey-chart/model.ts','components/charts/sankey-chart/context.tsx','components/charts/sankey-chart/plot.tsx','components/charts/sankey-chart/tooltip.tsx','components/previews/charts/sankey-chart.preview.tsx','components/previews/charts/sankey-chart.usage.tsx','tests/sankey-chart.a11y.test.tsx'];
await mkdir('docs/proof/v3-parity/charts/sankey/source', {recursive:true});
const inventory=[];
for (const path of files) {
  const bytes=await readFile(`${root}/${path}`);
  const archived=`docs/proof/v3-parity/charts/sankey/source/${path.replaceAll('/','__')}`;
  await copyFile(`${root}/${path}`,archived);
  inventory.push({path, archived, sha256:createHash('sha256').update(bytes).digest('hex')});
}
await writeFile('docs/proof/v3-parity/charts/sankey/source/pin.json',JSON.stringify({revision:execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),liveDeployment:'unknown',files:inventory},null,2));
