import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile,readFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {spawnSync} from 'node:child_process';

const [phase, revision, filter = 'both'] = process.argv.slice(2);
const root = 'docs/proof/v3-parity/charts/round4-candle-volume';
const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
await mkdir(`${root}/configs`,{recursive:true});
try {
  for (const chart of filter === 'both' ? ['candle','volume'] : [filter]) {
    for (const [theme,reducedMotion] of [['dark','no-preference'],['light','reduce']]) {
      const slug = chart === 'candle' ? 'candlestick-chart' : 'volume-profile';
      const live = phase === 'live';
      const url = live ? `https://beui.dev/charts/${slug}` : `http://127.0.0.1:18114/?chart=${chart}&theme=${theme}&width=576`;
      const context = await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,colorScheme:theme,reducedMotion});
      const page = await context.newPage();
      await page.goto(url,{waitUntil:'domcontentloaded'});
      await page.waitForTimeout(3000);
      if (live) await page.getByRole('tab',{name:`${theme === 'dark'?'Dark':'Light'} theme`,exact:true}).click();
      await page.locator('flt-semantics-placeholder').evaluateAll(nodes=>nodes.forEach(n=>n.click()));
      await page.waitForTimeout(500);
      const candidate = phase === 'before' || phase.startsWith('after');
      const plot = candidate ? await page.evaluate(chart => {
        const rect = globalThis.__beuiCapture.rect;
        return chart === 'candle' ? {x:rect.x,y:rect.y+rect.height-320,width:rect.width,height:320}
          : {x:rect.x+62.4,y:rect.y,width:rect.width-62.4,height:320};
      },chart) : await page.getByRole('slider').last().boundingBox();
      if (!plot) throw Error('Missing chart inspector');
      const candleWidth = plot.width - 64;
      const targets = {
        A:{x:plot.x + (chart==='candle'?candleWidth*10.5/48:plot.width*.4),y:plot.y+plot.height*(chart==='candle'?.25:13.5/24)},
        B:{x:plot.x + (chart==='candle'?candleWidth*32.5/48:plot.width*.6),y:plot.y+plot.height*(chart==='candle'?.65:10.5/24)},
        exit:{x:1100,y:200},
      };
      const script = phase === 'source' ? 'source.js' : 'main.dart.js';
      const scriptUrl = `http://127.0.0.1:18114/${script}`;
      const sha256 = live ? null : createHash('sha256').update(Buffer.from(await(await fetch(scriptUrl)).arrayBuffer())).digest('hex');
      const touch = process.env.ROUND4_TOUCH === '1';
      const events = touch ? [
        {atMs:500,type:'click',target:'A',caption:'Trusted touch inspects price A.'},
        {atMs:1400,type:'click',target:'B',caption:'Trusted touch inspects price B.'},
        {atMs:2300,type:'click',target:'A',caption:'Trusted touch returns to A.'},
      ] : [
        {atMs:500,type:'move',target:'A',caption:'Pointer A. Canonical candle 10 or price bin 10.'},
        {atMs:1300,type:'move',target:'B',caption:'Pointer B. Canonical candle 32 or price bin 13.'},
        {atMs:1420,type:'move',target:'A',caption:'Reverse to A during the readout transition.'},
        {atMs:2200,type:'move',target:'exit',caption:'Pointer leaves the whole plot.'},
        {atMs:2500,type:'click',target:'A',caption:'Native mouse click establishes inspector focus.'},
        {atMs:2700,type:'move',target:'exit',caption:'Pointer exits before keyboard input.'},
        ...[['Home',3000],['ArrowRight',3500],['End',4000],['Escape',4400],['r',4800],['i',5200],['ArrowUp',5600],['e',6000],['i',6500],['Home',7000]].map(([key,atMs])=>({atMs,type:'key',key,caption:`Native ${key} input. R replaces identities, E empties, I restores.`})),
      ];
      const config = {url,viewport:{width:1280,height:1000},theme,reducedMotion,reference:live,requireFlutterProbe:phase==='before'||phase.startsWith('after'),backend:'screenshots',loadWaitMs:500,targets,events,finalHoldMs:600,
        servedJs:live?undefined:{url:scriptUrl,sha256,revision},
        provenance:{phase,revision,pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',liveDeploymentSha:live?'unknown':undefined,plot,fixture:'fixture.dart and source.tsx',timerOverrides:'none',touch,transportSha256:createHash('sha256').update(await readFile(`${root}/transport.mjs`)).digest('hex')}};
      const name = `${phase}-${chart}-${theme}-${reducedMotion}${touch?'-touch':''}`;
      await writeFile(`${root}/configs/${name}.json`,JSON.stringify(config,null,2),{flag:'wx'});
      await context.close();
      const result = spawnSync(process.execPath,['tool/parity_capture.mjs',`${root}/configs/${name}.json`,`${root}/${name}`],{stdio:'inherit',env:{...process.env,PARITY_PLAYWRIGHT:resolve(`${root}/transport.mjs`),ROUND4_OBSERVATIONS:resolve(`${root}/${name}/observations.json`)}});
      if(result.status!==0) throw Error(`Capture ${name} failed`);
    }
  }
} finally {await browser.close();}
