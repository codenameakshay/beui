import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
const root='docs/proof/v3-parity/charts/round4-composition-funnel';
const out=`${root}/${process.argv[2]}`;
await mkdir(out);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const rows=[];
function decode(file) {
  const result=spawnSync('ffmpeg',['-v','error','-i',file,'-f','rawvideo','-pix_fmt','rgb24','pipe:1'],{maxBuffer:10_000_000});
  if(result.status)throw Error('PNG decode failed');
  return result.stdout;
}
try {
  for(const [theme,width,height] of [['dark',1000,1400],['light',1000,1400],['dark',600,1400]]) {
    for(const slug of ['composition-chart','funnel-chart']) {
      const states=slug==='composition-chart'?['bar','area']:['vertical','horizontal'];
      const pairs={};
      for(const source of [true,false]) {
        const page=await browser.newPage({viewport:{width,height},reducedMotion:'reduce'});
        const url=source?`http://127.0.0.1:18116/source/?slug=${slug}&theme=${theme}`:`http://127.0.0.1:18116/?slug=${slug}&theme=${theme}&previewWidth=752&captureProbe=1`;
        await page.goto(url);await page.waitForTimeout(4500);await page.evaluate(()=>document.fonts.ready);
        if(!source)await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
        await page.waitForTimeout(300);
        const scripts=await page.evaluate(()=>[...document.scripts].map(s=>s.src));
        for(const state of states) {
          if(state==='horizontal')await page.getByRole('button',{name:'Horizontal',exact:true}).click();
          await page.mouse.move(10,10);await page.waitForTimeout(700);
          let rect;
          if(source)rect=await page.locator('main svg').nth(state==='area'?1:0).boundingBox();
          else if(slug==='composition-chart')rect=await page.getByRole('slider').nth(state==='area'?1:0).evaluate(e=>e.parentElement.getBoundingClientRect().toJSON());
          else {
            const first=await page.getByRole('button',{name:/^Visitors: /}).boundingBox();
            rect={...first,width:state==='horizontal'?first.width*5:first.width,height:state==='horizontal'?first.height:first.height*5};
          }
          if(!rect)throw Error('Missing plot geometry');
          const file=`${theme}-${width}-${slug}-${state}-${source?'source':'candidate'}`;
          await page.screenshot({path:`${out}/${file}-native.png`});
          const clip={x:Math.floor(rect.x),y:Math.floor(rect.y),width:Math.round(rect.width),height:Math.round(rect.height)};
          const result=spawnSync('ffmpeg',['-v','error','-i',`${out}/${file}-native.png`,'-vf',`crop=${clip.width}:${clip.height}:${clip.x}:${clip.y}`,'-frames:v','1',`${out}/${file}-plot.png`]);
          if(result.status)throw Error('Native plot crop failed');
          pairs[state]??={};pairs[state][source?'source':'candidate']={file:`${file}-plot.png`,rect,clip,url,scripts,bytes:decode(`${out}/${file}-plot.png`)};
        }
        await page.close();
      }
      for(const state of states) {
        const {source,candidate}=pairs[state];
        const record={theme,viewport:{width,height},slug,state,source:{...source,bytes:undefined},candidate:{...candidate,bytes:undefined}};
        if(source.bytes.length!==candidate.bytes.length)record.diff={verdict:'different plot dimensions',sourceBytes:source.bytes.length,candidateBytes:candidate.bytes.length};
        else {
          const thresholds=[0,1,4,16];const counts=Object.fromEntries(thresholds.map(t=>[t,0]));let absolute=0,max=0;
          for(let i=0;i<source.bytes.length;i+=3){let delta=0;for(let j=0;j<3;j++){const d=Math.abs(source.bytes[i+j]-candidate.bytes[i+j]);absolute+=d;delta=Math.max(delta,d);}max=Math.max(max,delta);for(const t of thresholds)if(delta>t)counts[t]++;}
          record.diff={pixels:source.bytes.length/3,changedPixelsByMaxChannelThreshold:counts,meanAbsoluteChannelError:absolute/source.bytes.length,maxChannelError:max,verdict:counts[0]===0?'exact':'nonzero difference'};
        }
        rows.push(record);
      }
    }
  }
  await writeFile(`${out}/measured-pixels.json`,JSON.stringify(rows,null,2));
}finally{await browser.close();}
