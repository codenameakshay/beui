import assert from 'node:assert/strict';
import {mkdir,readFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
import {performance} from 'node:perf_hooks';
import {examples} from './inventory.mjs';
import {open,inspect,save,sha256,playwright} from './probe.mjs';

const [origin,batch,theme='light',motion='no-preference']=process.argv.slice(2);
const item=examples.find(item=>item.key==='editable');
const output=resolve(import.meta.dirname,batch,`${origin}-${theme}-${motion}-editable-keyboard`);
await mkdir(output,{recursive:true});
const {chromium}=await import(pathToFileURL(playwright));
const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
  const {page,environment,scripts,url,context}=await open(browser,origin,item,theme,motion);
  const script=scripts.find(script=>script.url.endsWith(origin==='source'?'/source.js':'/main.dart.js'));
  assert.equal(sha256(Buffer.from(await(await fetch(script.url)).arrayBuffer())),script.sha256);
  await save(join(output,'environment.json'),environment);
  await save(join(output,'scripts.json'),scripts);
  const start=performance.now(),events=[],targets={},observations=[],checks=[];
  const snapshot=async label=>{
    const observed=await inspect(page);
    observations.push({label,observed});
    await page.screenshot({path:join(output,`${label}.png`)});
    return observed;
  };
  const key=async key=>{events.push({atMs:Math.round(performance.now()-start)+400,type:'key',key});await page.keyboard.press(key);await page.waitForTimeout(220);};
  const pointer=async(type,x,y)=>{
    const target=`p${Object.keys(targets).length}`;targets[target]={x,y};
    events.push({atMs:Math.round(performance.now()-start)+400,type,target});
    if(type==='move')await page.mouse.move(x,y);else await page.mouse.click(x,y);
    await page.waitForTimeout(100);
  };
  const has=(state,text)=>state.controls.some(control=>control.name?.includes(text));
  await snapshot('rest');
  const inputs=environment.controls.filter(control=>control.tag==='INPUT');
  const cell=origin==='source'?inputs.find(control=>control.value==='Ava Cole'):inputs[3];
  await pointer('move',cell.rect.x+40,cell.rect.y+cell.rect.height/2);
  const trigger=(await inspect(page)).controls.find(control=>control.name==='Row 1 options'&&(control.role==='button'||control.tag==='BUTTON')) ?? (origin==='before'?{rect:{x:357,y:cell.rect.y+cell.rect.height/2-12,width:8,height:24}}:null);
  assert(trigger,'Native hover mounts row handle');
  await pointer('click',trigger.rect.x+trigger.rect.width*.8,trigger.rect.y+trigger.rect.height/2);
  await page.waitForTimeout(200);
  checks.push({name:'pointer opens menu',pass:has(await snapshot('open'),'Insert before')});
  await key('Escape');checks.push({name:'Escape dismisses menu',pass:!has(await snapshot('dismissed'),'Insert before')});
  await key('Enter');checks.push({name:'Enter reopens focused trigger',pass:has(await snapshot('keyboard-open'),'Insert before')});
  await key('Tab');await snapshot('first-item-focused');await key('Enter');
  const state=await snapshot('inserted-by-keyboard');
  const count=state.controls.filter(control=>control.tag==='INPUT').length;
  checks.push({name:'Tab Enter inserts exact row',actual:count,expected:inputs.length+3,pass:count===inputs.length+3});
  await save(join(output,'outcomes.json'),{origin,theme,motion,checks,observations});
  const recorder=resolve('tool/parity_capture.mjs');
  const config={url,theme,reducedMotion:motion,viewport:{width:1280,height:1000},loadWaitMs:origin==='source'?700:1500,backend:'screenshots',requireFlutterProbe:origin!=='source',servedJs:{url:script.url,sha256:script.sha256,revision:origin==='source'?'a76e57c9bbc2837e96420b2610e9c82a3271bb05':process.env.CANDIDATE_REVISION},provenance:{example:item.id,origin,recorderHash:sha256(await readFile(recorder)),sourceDeployment:'pinned-isolated-preview; live deployment revision unknown'},targets,events,finalHoldMs:800};
  await save(join(output,'record-config.json'),config);await context.close();
  console.log(JSON.stringify({origin,checks}));
  if(process.env.RECORD!=='0')await new Promise((resolve,reject)=>{
    const child=spawn(process.env.NODE_BINARY ?? '/opt/homebrew/bin/node',[recorder,join(output,'record-config.json'),join(output,'recording')],{env:{...process.env,PARITY_PLAYWRIGHT:playwright}});
    let log='';child.stdout.on('data',data=>log+=data);child.stderr.on('data',data=>log+=data);child.on('error',reject);
    child.on('exit',async code=>{await save(join(output,'record-log.json'),{code,log});code===0?resolve():reject(new Error(log));});
  });
}finally{await browser.close();}
