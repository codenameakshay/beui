import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync, execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const batch = process.argv[2];
const expected = process.env.EXPECTED_JS_SHA256;
const viewport = { width: 1280, height: Number(process.env.HEIGHT || 900) };
if (!batch || !expected) throw new Error('Supply new batch name and EXPECTED_JS_SHA256');
const output = path.join(root, batch);
await mkdir(output);
const url = 'http://127.0.0.1:8108/main.dart.js';
const actual = createHash('sha256').update(Buffer.from(await (await fetch(url)).arrayBuffer())).digest('hex');
await writeFile(path.join(output, 'served-build.json'), JSON.stringify({ url, checkedAt: new Date().toISOString(), expected, actual, match: actual === expected,
  head: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
  workingDiff: execFileSync('git', ['diff', '--', 'lib', 'example/lib', 'example/pubspec.yaml'], { encoding: 'utf8' }),
  baseline: '5ec78ac30e1274727ddd185a883346e4d908e6c8', source: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05',
}, null, 2));
if (actual !== expected) throw new Error(`Foreign build ${actual}`);
const runtime = '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const { chromium } = await import(runtime);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const tool = '/Users/codenameakshay/.t3/worktrees/beui/t3-655688e6/tool/parity_capture.mjs';
const reducedMotion = process.env.REDUCED || 'no-preference';
const toolHash = createHash('sha256').update(await readFile(tool)).digest('hex');
const cases = [
  { slug: 'card-folder', labels: ['Show card details', 'Open Saurabh Chauhan, card ending in 0806, expires 08/29'], events: [[600,'move',0],[1100,'click',0],[2000,'click',0],[2800,'click',1],[3600,'key','Enter'],[4400,'move','outside']] },
  { slug: 'feedback-widget', labels: ['Help us improve'], events: [[600,'click',0],[1400,'key','Escape'],[2200,'click',0],[3000,'key','Tab']] },
  { slug: 'prediction-market-card', labels: ['Update odds'], events: [[600,'click',0],[1600,'move','outside']] },
  { slug: 'knockout-bracket', labels: [], events: [[600,'move','outside']] },
  { slug: 'number', labels: ['Animate'], events: [[600,'click',0],[1500,'click',0],[1800,'click',0],[2700,'key','Enter']] },
  { slug: 'text-animation', labels: ['Next phrase'], events: [[600,'click',0],[900,'click',0],[1800,'click',0],[2800,'key','Enter']] },
  { slug: 'morphing-search-chips', labels: ['Search inspiration'], events: [[600,'click',0],[1300,'key','Escape'],[2100,'move','outside']] },
  { slug: 'prediction-market', labels: ['Sell'], events: [[600,'click',0],[1600,'move','outside']] },
  { slug: 'morphing-tabs', labels: ['General', 'Close Archive'], events: [[600,'click',0],[1500,'key','ArrowRight'],[2300,'key','ArrowLeft'],[3100,'click',1]] },
  { slug: 'project-folder', labels: ['Brand direction'], events: [[600,'move',0],[1400,'move','outside'],[2100,'click',0],[3000,'key','Escape']] },
  { slug: 'notification-stack', labels: ['3 notifications. Expand notifications.'], prefix:true, events: [[600,'move',0],[1500,'move','outside'],[2200,'click',0],[3100,'key','Tab']] },
  { slug: 'dynamic-island', labels: ['Call','Timer','Music','Dismiss'], events: [[600,'click',0],[1600,'click',1],[2600,'click',2],[3600,'click',3]] },
  { slug: 'availability-scheduler', labels: ['Add time range to Monday','Copy Monday hours to other days'], events: [[600,'click',0],[1700,'click',1],[2800,'key','Escape']] },
  { slug: 'morphing-search', labels: ['Find components'], events: [[600,'click',0],[1700,'key','Escape'],[2600,'move','outside']] },
  { slug: 'wallet-card', labels: ['Hide balance','Main Wallet','Simulate balance change'], events: [[600,'click',0],[1500,'click',0],[2400,'click',1],[3000,'key','Escape'],[3600,'click',2]] },
  { slug: 'bloom-menu', labels: ['Create\nCreate'], events: [[600,'click',0],[1500,'key','Escape'],[2300,'click',0],[3200,'click','outside']] },
  { slug: 'dock', labels: ['home','music','settings'], events: [[600,'move',0],[1400,'move',1],[2200,'move',2],[3000,'move','outside'],[3600,'click',0]] },
  { slug: 'signup-form', labels: [], events: [[600,'key','Tab'],[1500,'key','Tab'],[2400,'move','outside']] },
  { slug: 'infinite-masonry', labels: [], events: [[600,'move','outside']] },
];
try {
  for (const item of cases.filter(c => !process.env.SLUGS || process.env.SLUGS.split(',').includes(c.slug))) {
    for (const theme of (process.env.THEMES || 'dark').split(',')) {
      const candidate = process.env.TARGET !== 'reference';
      const sourceSlug = item.slug === 'prediction-market-card' ? 'prediction-market' : item.slug === 'morphing-search-chips' ? 'morphing-search' : item.slug;
      const pageUrl = candidate ? `http://127.0.0.1:8108/?slug=${item.slug}&theme=${theme}&previewWidth=592&captureProbe=1` : `https://beui.dev/components/${['number','text-animation','dock'].includes(item.slug) ? 'motion' : 'blocks'}/${sourceSlug}`;
      const context = await browser.newContext({ viewport, deviceScaleFactor:1, colorScheme:theme, reducedMotion });
      const page = await context.newPage();
      await page.goto(pageUrl);
      if (!candidate) await page.getByRole('tab',{name:`${theme === 'dark' ? 'Dark' : 'Light'} theme`,exact:true}).click();
      await page.waitForTimeout(3500);
      if (candidate) {
        await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
        await page.waitForTimeout(500);
      }
      const elements = await page.locator('[role],button,input').evaluateAll(es => es.map(e => {
        const r = e.getBoundingClientRect(); return {role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:e.textContent,x:r.x,y:r.y,width:r.width,height:r.height};
      }));
      const targets = { outside: { x:1100,y:100 } };
      const labels = item.labels.map(l => !candidate && item.slug === 'number' ? 'Animate card number' : l);
      labels.forEach((label,index) => {
        const found = elements.filter(e => ([e.label,e.text].includes(label) || item.prefix && (e.label || e.text || '').startsWith(label)) && e.width > 0 && e.y > 200 && e.y < viewport.height).sort((a,b) => a.width*a.height-b.width*b.height)[0];
        if (!found) throw new Error(`Missing ${item.slug} ${label}`);
        targets[index] = {x:found.x+found.width/2,y:found.y+found.height/2,measuredBounds:found};
      });
      const name = `${candidate ? 'candidate' : 'reference'}-${item.slug}-${theme}`;
      await writeFile(path.join(output, `${name}-elements.json`), JSON.stringify(elements,null,2));
      await page.screenshot({path:path.join(output,`${name}-rest.png`)});
      await context.close();
      const config = {url:pageUrl,viewport,theme,reducedMotion,reference:!candidate,requireFlutterProbe:candidate,servedJs:candidate?{url,sha256:expected,revision:`${execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim()} + round2 dirty diff`}:undefined,backend:'screenshots',loadWaitMs:3500,finalHoldMs:900,targets,
        provenance:{batch,expectedJsSha256:expected,tool,toolHash,source:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',liveDeploymentRevision:null,baselineWrapperApplied:false,candidatePreviewInnerWidth:candidate?592:null,wrapper:'d831524 source background and opt-in capture probe. Old baseline unchanged.',label:'Round2 observation, no native 60 FPS or exact-parity claim'},
        events:item.events.map(([atMs,type,v]) => type === 'key' ? {atMs,type,key:v} : {atMs,type,target:String(v)})};
      const file = path.join(output,`${name}.json`);
      await writeFile(file,JSON.stringify(config,null,2));
      const run = spawnSync(process.execPath,[tool,file,path.join(output,name)],{env:{...process.env,PARITY_PLAYWRIGHT:runtime},encoding:'utf8',timeout:180000});
      await writeFile(path.join(output,`${name}.log`),`${run.stdout}\n${run.stderr}\nexit=${run.status}\n`);
      if (run.status !== 0) throw new Error(`${name} failed`);
      console.log(name);
    }
  }
} finally { await browser.close(); }
