import {readFile,readdir,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {examples} from './inventory.mjs';

const root=import.meta.dirname;
const batches=(await readdir(root)).filter(name=>/^(native-final-|table-final-|menu-final-v3|menu-reduce-final|guard-final|metallic-head-|slider-guard-head-)/.test(name));
const runs=[];
for(const batch of batches)for(const name of await readdir(join(root,batch))) {
  const path=join(root,batch,name);
  let outcomes;try{outcomes=JSON.parse(await readFile(join(path,'outcomes.json'),'utf8'));}catch{continue;}
  let timeline;try{timeline=JSON.parse(await readFile(join(path,'recording/timeline.json'),'utf8'));}catch{}
  runs.push({path:`${batch}/${name}`,origin:outcomes.origin,theme:outcomes.theme,motion:outcomes.motion,
    example:outcomes.example?.id ?? 'example/table-editable/editable-keyboard',
    checks:outcomes.checks,recording:timeline?.stats ?? null});
}
const pixels=[];
for(const name of (await readdir(root)).filter(name=>name.startsWith('pixels-'))) {
  let report;try{report=JSON.parse(await readFile(join(root,name,'measurements.json'),'utf8'));}catch{continue;}
  pixels.push({path:`${name}/measurements.json`,supersededBy:name==='pixels-table-reduce'?'pixels-table-reduce-final/measurements.json':null,comparisons:report.results.length,
    compared:report.results.filter(result=>result.viewport).length,
    exactFailures:report.results.filter(result=>!result.viewport?.exactZero).length,
    rest:report.results.filter(result=>result.state==='rest').map(result=>({example:result.example,pixels:result.rawStage?.differentPixels,dimensions:result.rawStage?[result.rawStage.width,result.rawStage.height]:null}))});
}
const report={sourceRevision:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',liveSourceDeploymentRevision:'unknown',
  palette:'Matched isolated Blue fixtures. Blue is not source-default. Source-default and integrated theme selection are not certified.',
  candidateCommits:['fb88b230','ade59aeb','2af952c5','4935b8de','4162ac76','69d0030c','6a8ed389c'],verdict:'NOT_CERTIFIED',runs,pixels,
  failures:runs.flatMap(run=>run.checks.filter(check=>check.pass===false).map(check=>({path:run.path,...check}))),
  native60:'Not established. Original variable-cadence captures are retained without interpolation or duplication.'};
await writeFile(join(root,'report.json'),JSON.stringify(report,null,2)+'\n');
let index='# Native footage\n\nEach link is an original variable-frame-rate capture. No interpolation or synthetic 60 fps output is used.\n\n';
let html='<!doctype html><meta charset="utf-8"><title>Button, slider and table native proof</title><style>body{font:16px system-ui;max-width:1400px;margin:32px auto;padding:16px;background:#171717;color:#eee}section{margin:40px 0}.row{display:flex;gap:12px;flex-wrap:wrap}figure{margin:0;flex:1;min-width:300px}video{width:100%;background:#eee}figcaption{margin:8px 0}a{color:#8bc8ff}</style><h1>Button, slider and table native proof</h1><p>Pinned source a76e57c9. The live beui.dev deployment revision is unknown. Exact parity remains unapproved. The videos retain native measured cadence.</p>';
for(const item of examples){
  index+=`## ${item.id}\n\n`;
  html+=`<section><h2>${item.id}</h2><div class="row">`;
  const sliderFollowup=['wave','bubble'].includes(item.key);
  const finalBatch=sliderFollowup?'slider-guard-head-light':item.key==='metallic'?'metallic-head-light':item.family==='table'?'table-final-light':'native-final-light';
  const sourceBatch=sliderFollowup?'slider-guard-head-light':item.key==='metallic'?'metallic-head-light':'native-final-light';
  for(const [label,path]of [['Frozen before',`native-before-v3/before-light-no-preference-${item.key}/recording/capture.mp4`],['Pinned source',`${sourceBatch}/source-light-no-preference-${item.key}/recording/capture.mp4`],['After repairs',`${finalBatch}/after-light-no-preference-${item.key}/recording/capture.mp4`]]){
    index+=`- [${label}](${path}).\n`;
    html+=`<figure><figcaption>${label}</figcaption><video controls preload="none" src="${path}"></video></figure>`;
  }
  index+='\n';html+='</div></section>';
}
await writeFile(join(root,'FOOTAGE.md'),index.trimEnd()+'\n');
await writeFile(join(root,'footage.html'),html);
console.log(JSON.stringify({runs:runs.length,failedChecks:report.failures.length,pixelBatches:pixels.length}));
