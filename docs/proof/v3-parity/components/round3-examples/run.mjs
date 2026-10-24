import assert from 'node:assert/strict';
import {mkdir, readFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
import {performance} from 'node:perf_hooks';
import {examples} from './inventory.mjs';
import {open,inspect,save,sha256,playwright} from './probe.mjs';

const [origin,batch,theme='light',motion='no-preference',...keys] = process.argv.slice(2);
const {chromium} = await import(pathToFileURL(playwright));
const browser = await chromium.launch({headless:true,executablePath:process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const recorder = resolve('tool/parity_capture.mjs');
const recorderHash = sha256(await readFile(recorder));
await mkdir(resolve(import.meta.dirname,batch),{recursive:true});
try {
  for (const item of examples.filter(item => !keys.length || keys.includes(item.key))) {
    const output = resolve(import.meta.dirname,batch,`${origin}-${theme}-${motion}-${item.key}`);
    await mkdir(output);
    const {context,page,scripts,environment,url} = await open(browser,origin,item,theme,motion);
    const script = scripts.find(s => s.url.endsWith(origin==='source' ? '/source.js' : '/main.dart.js'));
    assert(script,'Actual served application JS was observed');
    const served = Buffer.from(await (await fetch(script.url)).arrayBuffer());
    assert.equal(sha256(served),script.sha256,'Served JS did not change before observations');
    await save(join(output,'scripts.json'),scripts);
    await save(join(output,'environment.json'),environment);
    const events=[],targets={},observations=[],checks=[];
    const start=performance.now();
    let targetId=0;
    const event=async (type,data={}) => {
      const action={atMs:Math.round(performance.now()-start)+400,type,...data};
      const before=performance.now();
      if(type==='move') await page.mouse.move(targets[data.target].x,targets[data.target].y);
      if(type==='click') await page.mouse.click(targets[data.target].x,targets[data.target].y);
      if(type==='down') await page.mouse.down();
      if(type==='up') await page.mouse.up();
      if(type==='key') await page.keyboard.press(data.key);
      if(type==='text') await page.keyboard.insertText(data.text);
      events.push(action);
      return {before,after:performance.now()};
    };
    const point=(x,y)=>{const key=`p${targetId++}`;targets[key]={x,y};return key;};
    const at=async (type,x,y)=>event(type,{target:point(x,y)});
    const wait=ms=>page.waitForTimeout(ms);
    const snapshot=async label=>{
      const observed=await inspect(page);
      observations.push({label,atMs:performance.now()-start,observed});
      await page.screenshot({path:join(output,`${label}.png`)});
      return observed;
    };
    const check=(name,actual,expected)=>checks.push({name,actual,expected,pass:actual===expected});
    const control=async name=>{
      const state=await inspect(page);
      return state.controls.find(c=>(c.role==='button'||c.tag==='BUTTON') && c.name?.replaceAll('\n','')===name) ?? state.controls.find(c=>c.name===name && c.rect.width<600);
    };
    const button=async name=>{
      const box=await page.getByRole('button',{name,exact:true}).boundingBox().catch(()=>null);
      const rect=box ?? (await control(name))?.rect;assert(rect,`Missing button ${name}`);
      return at('click',rect.x+rect.width/2,rect.y+rect.height/2);
    };
    const compact=text=>text?.replaceAll(/\s/g,'') ?? '';
    const has=(state,text)=>state.controls.some(c=>compact(c.name).includes(compact(text)) || c.value===text);
    const sliderValue=state=>{
      const slider=state.controls.find(c=>c.role==='slider');
      if(slider) return parseFloat(slider.value);
      const inline=state.controls.find(c=>c.role==='button' && c.name?.includes('pixels'));
      return inline ? Number(inline.name.match(/([\d.]+) pixels/)?.[1]) : null;
    };
    const firstRow=state=>state.controls.filter(c=>(c.tag==='TR'||c.tag==='FLT-SEMANTICS') && c.rect.height===52 && c.rect.width>450 && c.rect.y>=90 && /@beui.dev/.test(c.name)).sort((a,b)=>a.rect.y-b.rect.y)[0]?.name.trim().split(/\s+/).slice(0,2).join(' ');
    await snapshot('rest');
    try {
      if(item.family==='button') {
        if(item.key==='stateful') {
          for(const [idle,loading,result] of [['Save changes','Saving','Saved'],['Submit','Submitting','Failed']]) {
            await button(idle);await wait(650);
            let state=await snapshot(`${idle==='Submit'?'error':'success'}-loading`);
            check(`${idle} loading`,has(state,loading),true);
            const busy=state.controls.find(c=>compact(c.name).includes(compact(loading)) && (c.role==='button'||c.tag==='BUTTON'));
            check(`${idle} busy lockout`,busy?.disabled ?? false,true);
            if(busy) await at('click',busy.rect.x+busy.rect.width/2,busy.rect.y+busy.rect.height/2);
            await wait(1450);
            state=await snapshot(`${idle==='Submit'?'error':'success'}-result`);
            check(`${idle} result`,has(state,result),true);
            await wait(1800);
            state=await snapshot(`${idle==='Submit'?'error':'success'}-idle`);
            check(`${idle} idle`,has(state,idle),true);
          }
          await event('key',{key:'Tab'});await event('key',{key:'Enter'});await wait(300);
          await snapshot('keyboard-activation');
        } else {
          const controls=environment.controls.filter(c=>(c.role==='button'||c.tag==='BUTTON') && c.rect.width<600);
          check('exact preview control count',controls.length,item.key==='base'?10:3);
          for(let i=0;i<controls.length;i++) {
            const c=controls[i],x=c.rect.x+c.rect.width*.7,y=c.rect.y+c.rect.height/2;
            await at('move',x,y);await wait(160);
            await event('down');await wait(180);const held=await snapshot(`control-${i}-held`);
            const next=held.controls.filter(c=>(c.role==='button'||c.tag==='BUTTON')&&c.rect.width<600)[i];
            observations.push({label:`control-${i}-semantics-geometry`,rect:next?.rect,note:'Semantics bounds are not painted transform bounds. Compare native PNGs instead.'});
            await event('up');await wait(140);
          }
          await at('move',10,10);await wait(450);await snapshot('exit-reset');
          await event('key',{key:'Tab'});await event('key',{key:'Space'});await wait(200);await snapshot('keyboard');
        }
      } else if(item.family==='range-slider') {
        let state=environment;
        check('seed',sliderValue(state),item.seed);
        const sourceSlider=state.controls.find(c=>c.role==='slider');
        const x=item.key==='wave'?416:448,width=item.key==='wave'?448:384;
        const y=item.key==='ruler'?195:item.key==='stepped'?196:item.key==='wave'?194:item.key==='bubble'?208:180;
        await at('move',x+width*.3,y);await event('down');await wait(150);
        await at('move',x+width*.7,y);await wait(150);await snapshot('drag-held');
        await at('move',x+width*.85,y);await event('up');await wait(450);
        state=await snapshot('released');
        checks.push({name:'drag publishes value',actual:sliderValue(state),expected:'different from seed',pass:sliderValue(state)!==item.seed && sliderValue(state)!==null});
        if(origin==='source' && item.key==='stepped') await event('key',{key:'Tab'});
        for(const [key,expected] of [['Home',item.min],['End',item.max],['ArrowLeft',item.key==='inline'?112:item.max-item.step],['Home',item.min],['PageUp',item.key==='inline'?item.max:Math.min(item.max,item.min+item.step*10)],['PageDown',item.min],['ArrowRight',item.key==='inline'?24:item.min+item.step],['ArrowDown',item.min],['ArrowUp',item.key==='inline'?24:item.min+item.step]]) {
          await event('key',{key});await wait(220);state=await snapshot(`key-${key}-${observations.length}`);
          check(`key ${key}`,sliderValue(state),expected);
        }
        await at('move',10,10);await wait(200);await snapshot('exit');
      } else if(item.key==='data') {
        await button('Name');await wait(220);
        let state=await snapshot('sort-name');check('name ascending first row',firstRow(state),'Ava Cole');
        await event('key',{key:'Enter'});await wait(220);state=await snapshot('sort-keyboard');
        check('keyboard descending first row',firstRow(state),'Zoe Bose');
        const boxes=state.controls.filter(c=>c.role==='checkbox');
        const first=boxes[1] ?? boxes[0];
        if(first) {await at('click',first.rect.x+first.rect.width/2,first.rect.y+first.rect.height/2);await wait(200);state=await snapshot('selected');check('selected caption',has(state,'1 selected'),true);}
        const all=boxes[0];
        if(all) {await at('click',all.rect.x+all.rect.width/2,all.rect.y+all.rect.height/2);await wait(200);state=await snapshot('selected-all');check('all selected caption',has(state,'10,000 selected'),true);}
        const resize=state.controls.find(c=>c.name==='Resize name column'&&(c.role==='button'||c.tag==='BUTTON'));
        const rx=resize?resize.rect.x+3:494,ry=67;
        await at('move',rx,ry);await event('down');await at('move',rx+50,ry);await event('up');await wait(250);state=await snapshot('resized');
        const resized=state.controls.find(c=>c.name==='Resize name column'&&(c.role==='button'||c.tag==='BUTTON'));
        if(resize&&resized) check('single move resizes exactly 50px',resized.rect.x-resize.rect.x,50);
        const reorder=state.controls.find(c=>c.name==='Reorder name column'&&(c.role==='button'||c.tag==='BUTTON'));
        const hx=reorder?reorder.rect.x+12:421;
        await at('move',hx,67);await event('down');await at('move',hx+240,67);await event('up');await wait(250);state=await snapshot('reordered');
        const order=state.controls.filter(c=>/^Reorder .* column$/.test(c.name)&&(c.role==='button'||c.tag==='BUTTON')).sort((a,b)=>a.rect.x-b.rect.x).map(c=>c.name);
        check('reordered first column',order[0],'Reorder email column');
        await at('click',700,300);await event('key',{key:'PageDown'});await wait(250);await snapshot('virtual-scroll-keyboard');
      } else if(item.key==='editable') {
        const inputs=environment.controls.filter(c=>c.tag==='INPUT');
        const cell=origin==='source'?inputs.find(c=>c.value==='Ava Cole'):inputs[3];
        assert(cell,'Exact first body cell must exist');
        const x=cell.rect.x+20,y=cell.rect.y+cell.rect.height/2;
        await at('click',x,y);await event('key',{key:'Meta+a'});await event('text',{text:'Ava Edited'});await wait(200);
        let state=await snapshot('cell-edited');check('edit retained',has(state,'Ava Edited'),true);
        await event('key',{key:'Escape'});await wait(150);state=await snapshot('escape');check('source Escape retains live edit',state.controls.some(c=>c.value==='Ava Edited'||c.name?.includes('Ava Edited')),true);
        const toggle=state.controls.find(c=>c.role==='switch');
        if(toggle) {await at('click',toggle.rect.x+24,toggle.rect.y+14);await wait(200);state=await snapshot('read-only');check('read only',has(state,'Read-only.'),true);check('edit persisted in read-only',has(state,'Ava Edited'),true);}
        await at('click',toggle.rect.x+24,toggle.rect.y+14);await wait(200);
        state=await inspect(page);
        const header=state.controls.filter(c=>c.tag==='INPUT')[0];
        await at('click',header.rect.x+20,header.rect.y+header.rect.height/2);
        await event('key',{key:'Meta+a'});await event('text',{text:'Person'});await event('key',{key:'Tab'});await wait(200);
        await snapshot('column-renamed');
        const menu=async (kind,key,selection,label)=>{
          const current=await inspect(page),fields=current.controls.filter(c=>c.tag==='INPUT');
          const target=kind==='column'?fields[0]:fields.filter(c=>c.rect.y>fields[0].rect.y+35)[0];
          assert(target,`${kind} hover target`);
          const name=kind==='column'?`${key} column options`:'Row 1 options';
          await at('move',10,10);await wait(150);
          await at('move',target.rect.x+target.rect.width/2,target.rect.y+target.rect.height/2);await wait(80);
          const trigger=await control(name);
          assert(trigger,`Mounted ${kind} handle`);
          await at('click',trigger.rect.x+trigger.rect.width/2,trigger.rect.y+trigger.rect.height/2);await wait(250);
          await snapshot(`${label}-menu`);
          if(selection==='Escape') {
            await event('key',{key:'Escape'});await wait(100);
            check('Escape closes menu',has(await inspect(page),'Insert before'),false);
          } else {
            const entry=(await inspect(page)).controls.find(c=>c.name===selection&&c.rect.width<300);
            assert(entry,`Menu entry ${selection}`);
            await at('click',entry.rect.x+entry.rect.width/2,entry.rect.y+entry.rect.height/2);await wait(300);
          }
          return snapshot(label);
        };
        await menu('column','name','Escape','keyboard-dismiss');
        await menu('column','name','Insert before','column-inserted');
        await menu('column','field1','Delete column','column-deleted');
        await menu('row',null,'Insert before','row-inserted');
        await menu('row',null,'Delete row','row-deleted');
        for(let i=0;i<4;i++) await menu('row',null,'Delete row',`delete-to-empty-${i}`);
        state=await inspect(page);check('empty-state action',has(state,'Insert first row'),true);
        await button('Insert first row');await wait(300);state=await snapshot('first-row-restored');
        check('empty-state action inserts row',has(state,'Insert first row'),false);
      } else {
        check('initial loading',has(environment,'0 loaded') && has(environment,'Loading'),true);
        await wait(800);let state=await snapshot('initial-loaded');check('first page',has(state,'20 loaded'),true);
        await at('click',700,300);
        for(let i=0;i<7;i++) {await event('key',{key:'End'});await wait(1000);await snapshot(`page-${i+2}`);}
        state=await snapshot('end-reached');check('all eight pages',has(state,'160 loaded'),true);check('end status',has(state,'All loaded'),true);
      }
    } catch(error) {checks.push({name:'flow completed',pass:false,error:String(error)});}
    await save(join(output,'outcomes.json'),{example:item,origin,theme,motion,checks,observations});
    const config={url,theme,reducedMotion:motion,viewport:{width:1280,height:1000},loadWaitMs:origin==='source'?700:1500,backend:'screenshots',requireFlutterProbe:origin!=='source',servedJs:{url:script.url,sha256:script.sha256,revision:origin==='source'?'a76e57c9bbc2837e96420b2610e9c82a3271bb05':process.env.CANDIDATE_REVISION ?? '73e0d768+example-selection'},provenance:{example:item.id,origin,recorderHash,sourceDeployment:'pinned-isolated-preview; live deployment revision unknown'},targets,events,finalHoldMs:500};
    await save(join(output,'record-config.json'),config);
    await context.close();
    console.log(JSON.stringify({key:item.key,origin,checks,events:events.length}));
    if(process.env.RECORD!=='0') await new Promise((resolve,reject)=>{
      const child=spawn(process.env.NODE_BINARY ?? '/opt/homebrew/bin/node',[recorder,join(output,'record-config.json'),join(output,'recording')],{env:{...process.env,PARITY_PLAYWRIGHT:playwright}});
      let log='';child.stdout.on('data',data=>log+=data);child.stderr.on('data',data=>log+=data);
      child.on('error',reject);
      child.on('exit',async code=>{await save(join(output,'record-log.json'),{code,log});code===0?resolve():reject(new Error(log));});
    });
  }
} finally {await browser.close();}
