import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const [phase, revision, filter = 'both'] = process.argv.slice(2);
const root = 'docs/proof/v3-parity/charts/round4-candle-volume';
const browser = await chromium.launch({headless:true, executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
try {
  for (const chart of filter === 'both' ? ['candle','volume'] : [filter]) {
    for (const [theme,reducedMotion] of [['dark','no-preference'],['light','reduce']]) {
      const output = `${root}/stills-${phase}-${chart}-${theme}-${reducedMotion}`;
      await mkdir(output);
      const context = await browser.newContext({viewport:{width:1280,height:1000}, deviceScaleFactor:1, colorScheme:theme, reducedMotion});
      const page = await context.newPage();
      const scripts = [];
      const reads = [];
      page.on('response', response => {
        if (/\.js$/.test(response.url())) reads.push(response.body().then(bytes => scripts.push({url:response.url(),sha256:hash(bytes),bytes:bytes.length})));
      });
      await page.addInitScript(() => {
        globalThis.__inputs = [];
        for (const type of ['keydown','pointerdown','pointermove','pointerup','pointercancel']) document.addEventListener(type,e => globalThis.__inputs.push({type,key:e.key,pointerType:e.pointerType,isTrusted:e.isTrusted,x:e.clientX,y:e.clientY}),true);
      });
      await page.goto(`http://127.0.0.1:18114/?chart=${chart}&theme=${theme}&width=576`,{waitUntil:'domcontentloaded'});
      await page.waitForTimeout(3000);
      await page.locator('flt-semantics-placeholder').evaluateAll(nodes=>nodes.forEach(n=>n.click()));
      await page.evaluate(()=>document.fonts.ready);
      await page.waitForTimeout(500);
      const candidate = !phase.startsWith('source');
      const plot = candidate ? await page.evaluate(chart => {
        const r = globalThis.__beuiCapture.rect;
        return chart === 'candle' ? {x:r.x,y:r.y+r.height-320,width:r.width,height:320} : {x:r.x+62.4,y:r.y,width:r.width-62.4,height:320};
      },chart) : await page.getByRole('slider').last().boundingBox();
      const a = {x:plot.x+(chart==='candle'?(plot.width-64)*10.5/48:plot.width*.4),y:plot.y+plot.height*(chart==='candle'?.25:13.5/24)};
      const b = {x:plot.x+(chart==='candle'?(plot.width-64)*32.5/48:plot.width*.6),y:plot.y+plot.height*(chart==='candle'?.65:10.5/24)};
      const cdp = await context.newCDPSession(page);
      const states = [];
      const capture = async (name, wait = 1200) => {
        await page.waitForTimeout(wait);
        const state = await page.evaluate(() => ({viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio},reduce:matchMedia('(prefers-reduced-motion: reduce)').matches,canHover:matchMedia('(hover: hover) and (pointer: fine)').matches,probe:globalThis.__beuiCapture,inputs:globalThis.__inputs,
          focus:{tag:document.activeElement?.tagName,label:document.activeElement?.getAttribute('aria-label')},
          values:[...document.querySelectorAll('[aria-valuetext]')].map(e=>e.getAttribute('aria-valuetext')),
          boxes:[...document.querySelectorAll('[data-slot="volume-profile"],[data-slot="volume-profile-plot"],dl,[role="tooltip"]')].map(e=>({tag:e.tagName,slot:e.getAttribute('data-slot'),role:e.getAttribute('role'),rect:e.getBoundingClientRect().toJSON(),marginBottom:getComputedStyle(e).marginBottom})),
        }));
        if (state.reduce !== (reducedMotion === 'reduce')) throw Error('Ineffective browser motion preference');
        if (candidate && state.probe.disableAnimations !== state.reduce) throw Error('Ineffective Flutter motion preference');
        const result = await cdp.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
        const bytes = Buffer.from(result.data,'base64');
        await writeFile(`${output}/${name}.png`,bytes,{flag:'wx'});
        states.push({name,sha256:hash(bytes),...state});
      };
      await page.mouse.move(10,10);
      await capture('rest');
      await page.mouse.move(a.x,a.y);
      await capture('pointer-a');
      await page.mouse.move(b.x,b.y);
      await capture('pointer-b');
      await page.mouse.move(1100,200);
      await page.mouse.click(a.x,a.y);
      await page.mouse.move(1100,200);
      await page.keyboard.press('Home');
      await capture('home');
      await page.keyboard.press('End');
      await capture('end');
      await page.keyboard.press('Escape');
      await capture('escape');
      await page.keyboard.press('Home');
      await page.keyboard.press('r');
      await capture('replaced');
      await page.keyboard.press('i');
      await capture('restored');
      await page.keyboard.press('ArrowUp');
      await capture('reopened');
      await page.keyboard.press('e');
      await capture('empty');
      await page.keyboard.press('i');
      await capture('restored-empty');
      await page.mouse.click(1100,200);
      await cdp.send('Emulation.setTouchEmulationEnabled',{enabled:true});
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:a.x,y:a.y}]});
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
      await capture('touch-tap');
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:a.x,y:a.y}]});
      await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:a.x+8,y:a.y+2}]});
      await capture('touch-move',300);
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
      await capture('touch-release');
      await Promise.all(reads);
      await writeFile(`${output}/states.json`,JSON.stringify({phase,revision,plot,theme,reducedMotion,scripts,states},null,2),{flag:'wx'});
      console.log(output, scripts.find(s=>s.url.endsWith(candidate?'main.dart.js':'source.js'))?.sha256, states.map(s=>({name:s.name,values:s.values})));
      await context.close();
    }
  }
} finally {await browser.close();}
