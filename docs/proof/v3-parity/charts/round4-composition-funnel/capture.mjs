import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const root='docs/proof/v3-parity/charts/round4-composition-funnel';
const [phase,revision,build]=process.argv.slice(2);
const source=phase.startsWith('source');
const out=`${root}/captures-${phase}`;
await mkdir(out);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
try {
  for(const slug of ['composition-chart','funnel-chart']) {
    const viewport={width:1000,height:1400};
    const url=source?`http://127.0.0.1:18116/source/?slug=${slug}`:`http://127.0.0.1:18116/?slug=${slug}&previewWidth=752&captureProbe=1`;
    const page=await browser.newPage({viewport});
    await page.goto(url);await page.waitForTimeout(6000);await page.evaluate(()=>document.fonts.ready);
    if(!source)await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(300);
    await page.screenshot({path:`${out}/${slug}-probe.png`});
    const probe=await page.evaluate(()=>({flutter:globalThis.__beuiCapture??null,svgs:[...document.querySelectorAll('main svg')].map(e=>e.getBoundingClientRect().toJSON())}));
    await writeFile(`${out}/${slug}-probe.json`,JSON.stringify(probe,null,2));
    const pixels=spawnSync('ffmpeg',['-v','error','-i',`${out}/${slug}-probe.png`,'-f','rawvideo','-pix_fmt','rgb24','pipe:1'],{maxBuffer:10_000_000});
    if(pixels.status!==0)throw Error('PNG decoding failed');
    const bands=[];
    for(let y=0;y<viewport.height;y++) {
      let count=0;
      for(let x=124;x<876;x++) {
        const i=(y*viewport.width+x)*3;
        const values=[...pixels.stdout.subarray(i,i+3)];
        if(Math.max(...values)>65)count++;
      }
      if(count>75){if(!bands.length||bands.at(-1).bottom!==y)bands.push({y,bottom:y+1});else bands.at(-1).bottom=y+1;}
    }
    if(!bands.length)throw Error('No observed colored plot');
    let bottom=bands[0].bottom;
    for(const band of bands.slice(1)) {if(band.y-bottom>20)break;bottom=band.bottom;}
    let plot;
    if(source)plot=probe.svgs[0];
    else if(slug==='composition-chart')plot=await page.getByRole('slider').first().evaluate(e=>e.parentElement.getBoundingClientRect().toJSON());
    else {
      const first=await page.getByRole('button',{name:/^Visitors: /}).boundingBox();
      if(!first)throw Error('Missing first funnel stage');
      plot={...first,height:first.height*5};
    }
    probe.observedColoredBands=bands;
    probe.inspectedPlot=plot;
    await writeFile(`${out}/${slug}-observed-geometry.json`,JSON.stringify(probe,null,2));
    const targets={a:{x:plot.x+plot.width*.2,y:plot.y+plot.height*.3},b:{x:plot.x+plot.width*.7,y:plot.y+plot.height*.7},exit:{x:20,y:20}};
    const js=source?'source.js':'main.dart.js';
    const bytes=await readFile(`${build}/${js}`);
    for(const reducedMotion of ['no-preference','reduce']) {
      const config={url,viewport,theme:'dark',reducedMotion,requireFlutterProbe:!source,loadWaitMs:6000,backend:'screenshots',targets,servedJs:{url:`http://127.0.0.1:18116/${source?'source/':''}${js}`,sha256:createHash('sha256').update(bytes).digest('hex'),revision},provenance:{phase,pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',revision,build,plot,sourceWrapper:source?'Untouched charts; consumer wrapper controls replace shared demo buttons.':null},events:[{atMs:0,type:'move',target:'exit',caption:`${phase}: resting ${slug}`},{atMs:400,type:'move',target:'a',caption:'Native mouse inspects A'},{atMs:1000,type:'move',target:'b',caption:'Native mouse inspects B'},{atMs:1600,type:'click',target:'b',caption:'Mouse click retains keyboard inspection'},{atMs:1800,type:'move',target:'exit',caption:'Pointer leaves the plot'},{atMs:2200,type:'key',key:slug==='composition-chart'?'ArrowLeft':'Tab',caption:'Native keyboard after pointer exit'},{atMs:2800,type:'key',key:'Escape',caption:'Escape dismisses the readout'}],finalHoldMs:500};
      const configPath=`${out}/${slug}-${reducedMotion}.json`;
      await writeFile(configPath,JSON.stringify(config,null,2));
      const result=spawnSync(process.execPath,['tool/parity_capture.mjs',configPath,`${out}/${slug}-${reducedMotion}`],{env:{...process.env,PARITY_PLAYWRIGHT:'/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs'},stdio:'inherit'});
      if(result.status!==0)throw Error(`capture failed ${slug} ${reducedMotion}`);
    }
    await page.close();
  }
} finally {await browser.close();}
