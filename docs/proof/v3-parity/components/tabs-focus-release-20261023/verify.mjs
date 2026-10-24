import { readFile, writeFile, mkdir, readdir, copyFile } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import sharp from '/tmp/beui-v3-parity-components-source/node_modules/sharp/dist/index.cjs';

const root=import.meta.dirname;
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const json=async path=>JSON.parse(await readFile(path));
const runs=[];
await mkdir(join(root,'native-crops'),{recursive:true});
for(const motion of ['no-preference','reduce']) for(const theme of ['light','dark']) for(const phase of ['source','before','after']) {
  const id=`${phase}-${theme}-${motion}`,dir=join(root,id);
  const timeline=await json(join(dir,'timeline.json'));
  const environment=await json(join(dir,'environment.json'));
  const scripts=await json(join(dir,'scripts.json'));
  assert.deepEqual(environment.viewport,{width:1280,height:1000});
  assert.equal(environment.dpr,1);
  assert.equal(environment.reducedMotion,motion==='reduce');
  assert.equal(timeline.stats.video.decodedFrames,timeline.frames.length);
  assert.deepEqual(timeline.stats.video.width,1280);
  assert.deepEqual(timeline.stats.video.height,913);
  if(phase!=='source') {
    assert.equal(environment.flutterCapture.disableAnimations,motion==='reduce');
    assert.equal(environment.flutterCapture.platformDisableAnimations,motion==='reduce');
    assert.equal(environment.flutterCapture.constraints.maxWidth,592);
    assert.equal(environment.flutterCapture.motionOverride,null);
    assert.ok(scripts.some(s=>s.url===environment.servedJs.url&&s.sha256===environment.servedJs.sha256));
    const response=await fetch(environment.servedJs.url);
    assert.equal(response.status,200);
    assert.equal(hash(Buffer.from(await response.arrayBuffer())),environment.servedJs.sha256);
  } else {
    assert.equal(environment.stage[0].rect.width,592);
    assert.equal(environment.stage[0].rect.height,559);
  }
  for(const frame of timeline.frames) assert.equal(hash(await readFile(join(dir,frame.file))),frame.sha256,`${id} frame ${frame.index}`);
  const eventGaps=timeline.events.map(event=>{
    const before=timeline.frames.filter(f=>f.receivedMs<=event.dispatchBeforeMs).at(-1);
    const after=timeline.frames.find(f=>f.receivedMs>=event.dispatchAfterMs);
    return {...event,bracketingGapMs:before&&after?after.receivedMs-before.receivedMs:null};
  });
  const crop=phase==='source'?{left:376,top:794,width:180,height:46}:{left:416,top:695,width:180,height:46};
  const stateSamples=[];
  for(const [index,event] of timeline.events.entries()) {
    const next=timeline.events[index+1]?.dispatchBeforeMs??timeline.stats.stopMs;
    const frame=timeline.frames.filter(f=>f.requestedMs>=event.dispatchAfterMs+40&&f.receivedMs<next).at(-1);
    const sample={eventIndex:index,type:event.type,key:event.key,target:event.target};
    if(frame) {
      sample.file=frame.file;sample.sha256=frame.sha256;sample.requestedMs=frame.requestedMs;sample.receivedMs=frame.receivedMs;
      sample.crop=`native-crops/${id}-event-${index}.png`;
      await sharp(join(dir,frame.file)).extract(crop).png().toFile(join(root,sample.crop));
    }
    stateSamples.push(sample);
  }
  const last=timeline.frames.at(-1);
  const {data,info}=await sharp(join(dir,last.file)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const x=phase==='source'?600:700,y=850;
  const background=[...data.subarray((y*info.width+x)*4,(y*info.width+x)*4+4)];
  assert.ok(theme==='light'?background[0]>200:background[0]<50,`${id} effective native theme`);
  runs.push({id,environment,scripts,cadence:timeline.stats,eventGaps,stateSamples,settledThemePixel:{x,y,rgba:background}});
}
const native=await json(join(root,'native-checkpoints-reverse/results.json'));
assert.equal(native.length,72);
assert.equal(new Set(native.map(r=>r.id)).size,72);
for(const r of native) {
  assert.deepEqual(r.selected,[r.expected],r.id);
  assert.ok(!/<flt-semantics(?:\s|>)/.test(r.activeBeforeObservation),`${r.id} semantics absent before observation`);
}
for(const motion of ['no-preference','reduce']) for(const theme of ['light','dark']) for(const variant of ['pill','segment','underline']) {
  const find=phase=>native.find(r=>r.id===`${phase}-${theme}-${motion}-${variant}-keyboard-only`).buttons.map(b=>b.rect);
  assert.deepEqual(find('before'),find('after'),`${theme} ${motion} ${variant} unchanged trigger rectangles`);
}
const source=await json(join(root,'source-observations-scoped/results.json'));
assert.equal(source.length,12);
for(const r of source) for(const state of [r.end,r.left]) {
  assert.equal(state.filter(b=>b.tabIndex===0).length,1);
  assert.equal(state.filter(b=>b.focused).length,1);
  const focused=state.find(b=>b.focused);
  assert.equal(focused.style.background,'rgba(0, 0, 0, 0)');
  assert.equal(focused.style.boxShadow,'none');
  assert.ok(focused.style.outline.includes(r.variant==='underline'?'auto':'none'));
}
const focusPixels=[];
for(const motion of ['no-preference','reduce']) for(const theme of ['light','dark']) for(const phase of ['before','after']) {
  const id=`${phase}-${theme}-${motion}-underline-keyboard-only`;
  const file=join(root,'native-checkpoints-reverse',`${id}.png`);
  await sharp(file).extract({left:416,top:695,width:180,height:46}).png().toFile(join(root,'native-crops',`${id}.png`));
  const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const x=535,y=700;
  const rgba=[...data.subarray((y*info.width+x)*4,(y*info.width+x)*4+4)];
  const expected=phase==='before'?(theme==='light'?[127,182,234,255]:[58,97,146,255]):theme==='light'?[252,252,252,255]:[21,21,21,255];
  assert.deepEqual(rgba,expected,`${id} actual native focus interior`);
  focusPixels.push({id,x,y,rgba});
}
const builds=[];
await mkdir(join(root,'builds'),{recursive:true});
for(const [phase,revision,input,log] of [
  ['before','ce5564d267cc4bb98b258bbf27f4689ee48db8e9','/tmp/beui-tabs-release-dbLua8/after-input','/tmp/beui-tabs-release-dbLua8/after-frozen-build.log'],
  ['after','bd6df4189ebcfee751c453d1ff575b07bb417fbc','/tmp/beui-tabs-focus-release-Vt4CcG/input','/tmp/beui-tabs-focus-release-Vt4CcG/build.log'],
]) {
  const files=[];
  for(const file of ['lib/src/motion/tabs.dart','example/lib/demos/tabs_demo.dart','example/lib/visual_harness.dart','example/assets/fonts/Geist-Medium.ttf']) {
    const archived=await readFile(join(input,file));
    const committed=spawnSync('git',['show',`${revision}:${file}`],{maxBuffer:20000000});
    assert.equal(committed.status,0);
    assert.equal(hash(archived),hash(committed.stdout),`${phase} ${file}`);
    files.push({file,sha256:hash(archived)});
  }
  await copyFile(log,join(root,'builds',`${phase}.log`));
  await copyFile(join(input,'example/pubspec.lock'),join(root,'builds',`${phase}-pubspec.lock`));
  builds.push({phase,revision,input,files});
}
const golden=hash(await readFile('test/motion/goldens/beui_tabs.png'));
assert.equal(golden,'e2eb1d6214b68489aea42ba9e16626033b0621d62b0196f073218dac9b08a57d');
const pinnedSource='a76e57c9bbc2837e96420b2610e9c82a3271bb05';
const pinnedFile=await readFile('/tmp/beui-v3-parity-components-source/components/motion/tabs.tsx');
const committedSource=spawnSync('git',['-C','/tmp/beui-v3-parity-components-source','show',`${pinnedSource}:components/motion/tabs.tsx`],{maxBuffer:2000000});
assert.equal(committedSource.status,0);
assert.equal(hash(pinnedFile),hash(committedSource.stdout));
const manifest={productionCommit:'bd6df4189ebcfee751c453d1ff575b07bb417fbc',pinnedSource,pinnedTabsSha256:hash(pinnedFile),liveSourceRevision:'unknown',builds,runs,nativeCheckpoints:native,sourceObservations:source,focusPixels,presentation:await json(join(root,'videos-native/manifest.json')),preservedGoldenSha256:golden,limits:[
  'Tests and this evidence do not certify exact source pixel or timing parity.',
  'CSS viewport1280x1000 DPR1. Recorder PNG and raw video1280x913. Direct native checkpoint screenshots1280x1000. No scaling, duplication or interpolation.',
  'Source theme selection is a recorded post-hydration action. Initial environment may precede that theme change. Settled native pixels verify the theme.',
  'Source pill and segment suppress outlines. Flutter deliberately preserves an accessible2px outline. Underline source uses browser auto outline, not the Flutter token outline.',
  'Candidate half-pixel placement, fractional text widths, colors and stage height remain different.',
  'native-checkpoints and native-checkpoints-paced retain failed keyboard setup attempts. native-checkpoints-reverse is authoritative. Source-observations retains an unscoped-locator attempt; source-observations-scoped is authoritative.',
  'Snapshot input timestamps bound exposure. Cadence is not native60fps or exact spring trajectory proof.',
]};
await writeFile(join(root,'manifest.json'),JSON.stringify(manifest,null,2));
const hashes=[];
async function walk(dir) {
  for(const e of await readdir(dir,{withFileTypes:true})) {
    const path=join(dir,e.name);
    if(e.isDirectory()) await walk(path);
    else if(e.name!=='hashes.json') hashes.push({file:relative(root,path),sha256:hash(await readFile(path))});
  }
}
await walk(root);
await writeFile(join(root,'hashes.json'),JSON.stringify(hashes,null,2));
console.log(JSON.stringify({runs:runs.map(r=>({id:r.id,frames:r.cadence.frames,fps:r.cadence.measuredFps,maxIntervalMs:r.cadence.maxIntervalMs})),nativeCheckpoints:native.length,sourceObservations:source.length,focusPixels,hashedFiles:hashes.length},null,2));
