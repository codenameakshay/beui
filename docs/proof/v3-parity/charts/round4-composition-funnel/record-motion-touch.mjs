import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
const root='docs/proof/v3-parity/charts/round4-composition-funnel';
const [phase,base]=process.argv.slice(2);
const out=`${root}/captures-input-${phase}`;
await mkdir(out);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
try {
  for(const slug of ['composition-chart','funnel-chart']) {
    for(const preference of ['no-preference','reduce']) {
      const config=JSON.parse(await readFile(`${root}/captures-${base}/${slug}-${preference}.json`));
      config.provenance.inputRound=phase;
      const page=await browser.newPage({viewport:config.viewport,reducedMotion:preference});
      await page.goto(config.url);await page.waitForTimeout(4000);
      if(!phase.startsWith('source'))await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
      await page.waitForTimeout(500);
      if(slug==='funnel-chart') {
        const boxes={};
        for(const name of ['Next cohort','Horizontal','Vertical']) {
          const locator=page.getByRole('button',{name,exact:true});
          const rect=await locator.boundingBox();
          if(!rect)throw Error(`Missing ${name}`);
          boxes[name]=rect;
          config.targets[name]={x:rect.x+rect.width/2,y:rect.y+rect.height/2};
        }
        config.provenance.observedControls=boxes;
        config.events=[{atMs:0,type:'move',target:'exit',caption:'Settled canonical funnel'},{atMs:400,type:'click',target:'Next cohort',caption:'Native cohort replacement starts the 280ms path tween'},{atMs:500,type:'click',target:'Next cohort',caption:'Second cohort interrupts the displayed path'},{atMs:1300,type:'click',target:'Horizontal',caption:'Native direction change preserves stage identities'},{atMs:2100,type:'click',target:'Vertical',caption:'Return to vertical geometry'},{atMs:2800,type:'click',target:'Next cohort',caption:'Return to canonical cohort'}];
        const file=`${out}/${slug}-motion-${preference}.json`;
        await writeFile(file,JSON.stringify(config,null,2));
        const result=spawnSync(process.execPath,['tool/parity_capture.mjs',file,`${out}/${slug}-motion-${preference}`],{env:{...process.env,PARITY_PLAYWRIGHT:'/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs'},stdio:'inherit'});
        if(result.status)throw Error('motion capture failed');
      }
      config.events=[{atMs:400,type:'click',target:'a',caption:'Trusted touch inspects stage or period A'},{atMs:1100,type:'click',target:'a',caption:'Second trusted touch on the same target'},{atMs:1800,type:'click',target:'a',caption:'Third trusted touch on the same target'},{atMs:2500,type:'click',target:'b',caption:'Trusted touch inspects B'},{atMs:2800,type:'click',target:'a',caption:'Trusted touch returns to A'}];
      const wrapper=resolve('test/charts/touch_capture_round3.mjs');
      config.provenance.touchWrapper={path:wrapper,sha256:createHash('sha256').update(await readFile(wrapper)).digest('hex')};
      const file=`${out}/${slug}-touch-${preference}.json`;
      await writeFile(file,JSON.stringify(config,null,2));
      const result=spawnSync(process.execPath,['tool/parity_capture.mjs',file,`${out}/${slug}-touch-${preference}`],{env:{...process.env,PARITY_PLAYWRIGHT:wrapper,PARITY_TOUCH_OBSERVATION:resolve(`${out}/${slug}-touch-${preference}/observed-touch.json`)},stdio:'inherit'});
      if(result.status)throw Error('touch capture failed');
      await page.close();
    }
  }
}finally{await browser.close();}
