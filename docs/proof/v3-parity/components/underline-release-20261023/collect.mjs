import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const root = join(import.meta.dirname,process.argv[2] || 'verified');
await mkdir(root);
await mkdir(join(root,'observations'));
await mkdir(join(root,'configs'));
const revisions = {before:'a4685504',after:'ce5564d267cc4bb98b258bbf27f4689ee48db8e9'};
const ports = {before:8111,after:8112};
const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const results = [];
try {
  for (const theme of ['light','dark']) for (const phase of ['source','before','after']) {
    const source = phase === 'source';
    const id = `${phase}-${theme}`;
    const url = source ? 'https://beui.dev/components/motion/tabs' : `http://127.0.0.1:${ports[phase]}/?slug=tabs&theme=${theme}&color=Blue&previewWidth=592&captureProbe=1`;
    const context = await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,colorScheme:theme,reducedMotion:'no-preference'});
    const page = await context.newPage();
    await page.goto(url,{waitUntil:'domcontentloaded'});
    await page.waitForTimeout(5000);
    if (source) {
      await page.getByRole('tab',{name:`${theme === 'light'?'Light':'Dark'} theme`,exact:true}).click();
      await page.waitForTimeout(1000);
    }
    await page.evaluate(()=>document.fonts.ready);
    const snapshot = () => page.evaluate(source => {
      const list = source ? [...document.querySelectorAll('[role=tablist]')].find(e=>e.className.includes('border-b') && e.textContent.includes('Closed')) : null;
      const elements = source ? [...list.querySelectorAll('[role=tab]')] : [...document.querySelectorAll('flt-semantics[role=button]')].filter(e=>['All','Open','Closed'].includes(e.textContent));
      return {scroll:{x:scrollX,y:scrollY},dpr:devicePixelRatio,probe:globalThis.__beuiCapture??null,active:{tag:document.activeElement?.tagName,text:document.activeElement?.textContent?.slice(0,80)},list:list?.getBoundingClientRect().toJSON(),buttons:elements.map(e=>({name:e.textContent,rect:e.getBoundingClientRect().toJSON(),selected:e.getAttribute(source?'aria-selected':'aria-current'),focused:e===document.activeElement,style:source?{font:getComputedStyle(e).font,padding:getComputedStyle(e).padding,color:getComputedStyle(e).color,background:getComputedStyle(e).backgroundColor}:null})),indicator:list?.querySelector('.bg-primary')?.getBoundingClientRect().toJSON(),indicatorColor:list?.querySelector('.bg-primary')?getComputedStyle(list.querySelector('.bg-primary')).backgroundColor:null};
    },source);
    if (!source) {
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await page.waitForTimeout(300);
    }
    const initial = await snapshot();
    const targets = Object.fromEntries(initial.buttons.map(b=>[b.name.toLowerCase(),{x:b.rect.x+b.rect.width/2,y:b.rect.y+b.rect.height/2}]));
    targets.outside = {x:100,y:100};
    const states = [];
    const save = async name => {
      await page.waitForTimeout(650);
      states.push({name,...await snapshot()});
      await page.screenshot({path:join(root,'observations',`${id}-${name}.png`)});
    };
    await page.mouse.move(100,100);
    await save('default');
    await page.mouse.move(targets.open.x,targets.open.y);
    await save('hover');
    await page.mouse.down();
    await save('down');
    await page.mouse.up();
    await save('selected');
    await page.mouse.move(100,100);
    await page.keyboard.press('End');
    await save('pointer-end');
    await page.keyboard.press('ArrowLeft');
    await save('pointer-left');
    if (!source) {
      await page.keyboard.press('Shift+Tab');
      await save('keyboard-focus');
      await page.keyboard.press('Home');
      await save('home');
      await page.keyboard.press('End');
      await save('end');
      await page.keyboard.press('ArrowLeft');
      await save('left');
    }
    await writeFile(join(root,'observations',`${id}.json`),JSON.stringify({id,url,theme,phase,initial,states,observerSetup:source?'Theme tab clicked.':'Flutter semantics enabled by placeholder click for DOM observation only.'},null,2));
    const servedJs = source ? undefined : {url:`http://127.0.0.1:${ports[phase]}/main.dart.js`,sha256:createHash('sha256').update(await readFile(`/tmp/beui-tabs-release-dbLua8/${phase}-frozen-web/main.dart.js`)).digest('hex'),revision:revisions[phase]};
    const events = [
      {atMs:500,type:'move',target:'open'},
      {atMs:1000,type:'down',target:'open'},
      {atMs:1250,type:'up',target:'open'},
      {atMs:2100,type:'move',target:'outside'},
      {atMs:2300,type:'key',key:'End'},
      {atMs:3200,type:'key',key:'ArrowLeft'},
    ];
    if (!source) events.push({atMs:4100,type:'key',key:'Shift+Tab'},{atMs:4400,type:'key',key:'Home'},{atMs:5300,type:'key',key:'End'},{atMs:6200,type:'key',key:'ArrowLeft'});
    if (source) {
      targets.theme = {role:'tab',name:`${theme === 'light'?'Light':'Dark'} theme`};
      for (const event of events) event.atMs += 1000;
      events.unshift({atMs:0,type:'click',target:'theme'});
    }
    const config = {url,viewport:{width:1280,height:1000},theme,reference:false,backend:'screenshots',reducedMotion:'no-preference',requireFlutterProbe:!source,servedJs,loadWaitMs:5000,finalHoldMs:1000,targets,events,provenance:{phase,revision:source?'live deployment unknown; pinned correspondence a76e57c9bbc2837e96420b2610e9c82a3271bb05':revisions[phase],wrapper:source?'Live documentation stage, 592px preview, 448px demo':'Unmodified visual_harness.dart, previewWidth=592, 448px Tabs demo',observation:'Source theme click is recorded after hydration. DOM replay with semantics enabled is separate from unmodified recorder native capture. Native keyboard outcomes must be checked from frames.'}};
    await writeFile(join(root,'configs',`${id}.json`),JSON.stringify(config,null,2));
    results.push({id,url,initial,states:states.map(s=>({name:s.name,selected:s.buttons.filter(b=>b.selected==='true').map(b=>b.name),focused:s.buttons.filter(b=>b.focused).map(b=>b.name),active:s.active,indicator:s.indicator}))});
    console.log(id,JSON.stringify(results.at(-1)));
    await context.close();
  }
  await writeFile(join(root,'observations','summary.json'),JSON.stringify(results,null,2));
} finally {await browser.close();}
