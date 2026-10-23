import assert from 'node:assert/strict';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const out = `${root}/${process.argv[2] ?? 'quick-touch-native'}`;
await mkdir(out);
const provenance = JSON.parse(await readFile(`${root}/build-provenance-quick-final.json`));
const browser = await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const rows = [];
try {
  for (const preference of ['no-preference','reduce']) {
    for (const source of [true,false]) {
      for (let repeat=0;repeat<(source?1:3);repeat++) {
        const id = `${source?'source':'candidate'}-${preference}-${repeat}`;
        const page = await browser.newPage({viewport:{width:1000,height:1400},reducedMotion:preference,hasTouch:true});
        const scripts = [];
        const pending = [];
        page.on('response',response => {
          if (response.url().endsWith(source?'/source.js':'/main.dart.js')) pending.push(response.body().then(bytes=>scripts.push({url:response.url(),sha256:createHash('sha256').update(bytes).digest('hex')})));
        });
        await page.goto(`http://127.0.0.1:18116/${source?'source/':''}?slug=composition-chart&previewWidth=752&captureProbe=1`);
        await page.waitForTimeout(4500);
        await page.evaluate(()=>document.fonts.ready);
        if (!source) await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
        await page.waitForTimeout(400);
        await Promise.all(pending);
        assert(scripts.some(script=>script.sha256===(source?provenance.sourceJavascriptSha256:provenance.candidateJavascriptSha256)));
        const motion = await page.evaluate(()=>({browser:matchMedia('(prefers-reduced-motion: reduce)').matches,flutter:globalThis.__beuiCapture??null}));
        assert.equal(motion.browser,preference==='reduce');
        if (!source) {
          assert.equal(motion.flutter.disableAnimations,preference==='reduce');
          assert.equal(motion.flutter.platformDisableAnimations,preference==='reduce');
          assert.equal(motion.flutter.motionOverride,null);
        }
        const bounds = source?await page.locator('main svg').first().boundingBox():await page.getByRole('slider').first().evaluate(e=>e.parentElement.getBoundingClientRect().toJSON());
        const a={x:bounds.x+bounds.width*.2,y:bounds.y+bounds.height*.3};
        const b={x:bounds.x+bounds.width*.7,y:a.y};
        const states=[];
        const check=async(name,expected)=>{
          await page.waitForTimeout(450);
          const text=await page.evaluate(source=>source?[...document.querySelectorAll('[role="tooltip"]')].filter(e=>getComputedStyle(e).visibility!=='hidden').map(e=>e.textContent).join('\n'):[...document.querySelectorAll('flt-semantics')].filter(e=>!e.querySelector('flt-semantics')).map(e=>e.textContent).filter(text=>/Organic search\n[\d,]+ visits/.test(text)).join('\n'),source);
          const screenshot=`${id}-${name}.png`;
          await page.screenshot({path:`${out}/${screenshot}`});
          states.push({name,expected,text,pass:expected===null?text==='':text.includes(expected),screenshot});
        };
        await check('rest',null);
        for(let tap=1;tap<=3;tap++){await page.touchscreen.tap(a.x,a.y);await check(`tap-${tap}`,null);}
        const cdp=await page.context().newCDPSession(page);
        await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[a]});
        await check('held-a','Aug 8');
        await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[b]});
        await check('drag-b','Aug 26');
        await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
        await check('release',null);
        rows.push({id,revision:source?provenance.pinnedSource:provenance.revision,scripts,motion,bounds,states});
        await page.close();
      }
    }
  }
  await writeFile(`${out}/states.json`,JSON.stringify(rows,null,2),{flag:'wx'});
  const states=rows.flatMap(row=>row.states);
  console.log(JSON.stringify({cases:rows.length,states:states.length,pass:states.filter(state=>state.pass).length}));
  assert(states.every(state=>state.pass));
} finally {await browser.close();}
