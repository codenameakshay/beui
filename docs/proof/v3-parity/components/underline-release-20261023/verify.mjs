import { readFile, writeFile, mkdir, readdir, copyFile } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import sharp from '/tmp/beui-v3-parity-components-source/node_modules/sharp/dist/index.cjs';

const root = import.meta.dirname;
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const json = async path => JSON.parse(await readFile(path));
const runs = [];
const samples = {};
await mkdir(join(root,'native-crops'),{recursive:true});
for (const id of ['source-light-final','source-dark-final','before-light','after-light','before-dark','after-dark']) {
  const dir = join(root,id);
  const timeline = await json(join(dir,'timeline.json'));
  const environment = await json(join(dir,'environment.json'));
  assert.equal(environment.dpr,1);
  assert.deepEqual(environment.viewport,{width:1280,height:1000});
  assert.equal(timeline.stats.video.decodedFrames,timeline.frames.length);
  const source = id.startsWith('source');
  if (!source) {
    assert.equal(environment.flutterCapture.disableAnimations,false);
    assert.equal(environment.flutterCapture.platformDisableAnimations,false);
    assert.equal(environment.flutterCapture.constraints.maxWidth,592);
    const scripts = await json(join(dir,'scripts.json'));
    assert.ok(scripts.some(s=>s.url===environment.servedJs.url && s.sha256===environment.servedJs.sha256));
    const response = await fetch(environment.servedJs.url);
    assert.equal(response.status,200);
    assert.equal(hash(Buffer.from(await response.arrayBuffer())),environment.servedJs.sha256);
  } else {
    assert.equal(environment.stage[0].rect.width,592);
    assert.equal(environment.stage[0].rect.height,559);
  }
  for (const frame of timeline.frames) assert.equal(hash(await readFile(join(dir,frame.file))),frame.sha256,`${id} frame ${frame.index}`);
  const eventGaps = timeline.events.map(event=>{
    const before = timeline.frames.filter(f=>f.receivedMs<=event.dispatchBeforeMs).at(-1);
    const after = timeline.frames.find(f=>f.receivedMs>=event.dispatchAfterMs);
    return {type:event.type,key:event.key,target:event.target,requestedMs:event.requestedMs,dispatchBeforeMs:event.dispatchBeforeMs,dispatchAfterMs:event.dispatchAfterMs,dispatchDelayMs:event.dispatchBeforeMs-event.requestedMs,bracketingGapMs:before&&after?after.receivedMs-before.receivedMs:null,firstAfterFrame:after?.index};
  });
  const at = source?1250:200;
  const frame = timeline.frames.reduce((a,b)=>Math.abs(b.receivedMs-timeline.stats.sequenceStartMs-at)<Math.abs(a.receivedMs-timeline.stats.sequenceStartMs-at)?b:a);
  const file = join(dir,frame.file);
  const {data,info} = await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  assert.deepEqual([info.width,info.height],[1280,913]);
  const crop = source?{left:376,top:794,width:180,height:46}:{left:416,top:695,width:180,height:46};
  await sharp(file).extract(crop).png().toFile(join(root,'native-crops',`${id}-default.png`));
  const stateSamples = [];
  for (const [index,event] of timeline.events.entries()) {
    const next = timeline.events[index+1]?.dispatchBeforeMs ?? timeline.stats.stopMs;
    const eligible = timeline.frames.filter(f=>f.requestedMs>=event.dispatchAfterMs+40&&f.receivedMs<next);
    const selected = eligible.at(-1);
    const sample = {eventIndex:index,type:event.type,key:event.key,target:event.target,eligibleFrames:eligible.length};
    if (selected) {
      sample.file = selected.file;
      sample.sha256 = selected.sha256;
      sample.requestedMs = selected.requestedMs;
      sample.receivedMs = selected.receivedMs;
      sample.crop = `native-crops/${id}-event-${index}.png`;
      await sharp(join(dir,selected.file)).extract(crop).png().toFile(join(root,sample.crop));
    }
    stateSamples.push(sample);
  }
  const pixel = (x,y)=>[...data.subarray((y*info.width+x)*4,(y*info.width+x)*4+4)];
  samples[id] = {data,info};
  const linePixels = source?[837,838,839].map(y=>({x:390,y,rgba:pixel(390,y)})):[737,738,739,740].map(y=>({x:430,y,rgba:pixel(430,y)}));
  const background = source?pixel(600,850):pixel(700,850);
  assert.ok(id.includes('light')?background[0]>200:background[0]<50,`${id} effective native theme`);
  runs.push({id,stats:timeline.stats,eventGaps,stateSamples,environment,scripts:await json(join(dir,'scripts.json')),defaultSample:{frame:frame.file,sha256:frame.sha256,requestedSequenceMs:at,receivedSequenceMs:frame.receivedMs-timeline.stats.sequenceStartMs,crop,linePixels,background}});
}
const pixelDiffs = [];
for (const theme of ['light','dark']) {
  const before = samples[`before-${theme}`];
  const after = samples[`after-${theme}`];
  let count=0,minX=Infinity,minY=Infinity,maxX=-1,maxY=-1;
  const regions = {underline:[],outside:[]};
  for (let i=0;i<before.data.length;i+=4) if (!before.data.subarray(i,i+4).equals(after.data.subarray(i,i+4))) {
    count++;
    const x=i/4%before.info.width,y=Math.floor(i/4/before.info.width);
    regions[x>=416&&x<595&&y>=695&&y<741?'underline':'outside'].push({x,y,before:[...before.data.subarray(i,i+4)],after:[...after.data.subarray(i,i+4)]});
    minX=Math.min(x,minX);maxX=Math.max(x,maxX);minY=Math.min(y,minY);maxY=Math.max(y,maxY);
  }
  pixelDiffs.push({theme,count,bounds:{minX,minY,maxX,maxY},regions,scope:'Full native default PNG. No alignment, scaling, interpolation, or color conversion. Other demo-region differences are retained separately, not discarded.'});
  assert.ok(count>0);
  assert.equal(regions.underline.length,84);
  assert.ok(regions.underline.every(p=>p.x>=416&&p.x<=457&&p.y>=738&&p.y<=739));
}
const golden = 'test/motion/goldens/beui_tabs.png';
const goldenSha256 = hash(await readFile(golden));
assert.equal(goldenSha256,'e2eb1d6214b68489aea42ba9e16626033b0621d62b0196f073218dac9b08a57d');
const provenance = [];
await mkdir(join(root,'builds'),{recursive:true});
for (const [phase,revision,input] of [['before','a4685504','root-before'],['after','ce5564d267cc4bb98b258bbf27f4689ee48db8e9','after-input']]) {
  const base = `/tmp/beui-tabs-release-dbLua8/${input}`;
  const files = ['lib/src/motion/tabs.dart','example/lib/visual_harness.dart','example/lib/demos/tabs_demo.dart','example/lib/explorer/capture_probe.dart','example/lib/explorer/explorer_app.dart','example/pubspec.yaml','pubspec.yaml'];
  const inputs = [];
  for (const file of files) {
    const bytes = await readFile(join(base,file));
    const committed = spawnSync('git',['show',`${revision}:${file}`],{maxBuffer:10000000});
    assert.equal(committed.status,0);
    assert.equal(hash(bytes),hash(committed.stdout));
    inputs.push({file,sha256:hash(bytes),matchesCommit:true});
  }
  for (const file of ['Geist-Regular.ttf','Geist-Medium.ttf','Geist-SemiBold.ttf','Geist-Bold.ttf']) inputs.push({file:`example/assets/fonts/${file}`,sha256:hash(await readFile(join(base,'example/assets/fonts',file)))});
  await copyFile(`/tmp/beui-tabs-release-dbLua8/${phase}-frozen-build.log`,join(root,'builds',`${phase}.log`));
  await copyFile(join(base,'example/pubspec.lock'),join(root,'builds',`${phase}-pubspec.lock`));
  provenance.push({phase,revision,inputs,buildRoot:base,output:`/tmp/beui-tabs-release-dbLua8/${phase}-frozen-web`,command:'flutter build web -t lib/visual_harness.dart --output <isolated-output>',flutter:'3.47.1 stable',dart:'3.13.1',note:'git archive input. Flutter generated only build/dependency files and analysis exclusions in the isolated export. No theme or font changes.'});
}
const nativeReplay = await json(join(root,'native-replay/results.json'));
assert.equal(nativeReplay.length,20);
const presentation = await json(join(root,'videos-native/manifest.json'));
const manifest = {verifiedAt:new Date().toISOString(),sourcePinnedCorrespondence:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',sourceDeployment:'unknown live deployment; observed script hashes retained per run',provenance,runs,pixelDiffs,golden:{path:golden,sha256:goldenSha256,unchanged:true},nativeReplayCheckpoints:nativeReplay.length,presentation,limits:['No exact parity claim. Native timing is not 60fps proof.','CSS viewport 1280x1000 DPR1; screenshot backend PNG and raw video are 1280x913. Complete underline remains visible.','Source theme selection occurs as the first recorded action after hydration. Initial environment may still report dark before that action. Native settled frame verifies requested theme.','Semantics-enabled replay differs from native pointer focus. Native-replay checks enable semantics only after input and screenshot.','Source and candidate stage width592 and demo width448 agree. Placement, stage height and fractional font metrics differ.','Original source-light attempt is actual dark because an early pre-hydration click had no effect. Verified and final source recaptures are separately retained.','videos contains a rejected presentation attempt with unchanged frame count but quantized timestamps. videos-native explicitly sets encoder time base and verifies every PTS.']};
await writeFile(join(root,'manifest.json'),JSON.stringify(manifest,null,2));
const hashes = [];
async function walk(dir) {
  for (const entry of await readdir(dir,{withFileTypes:true})) {
    const path = join(dir,entry.name);
    if (entry.isDirectory()) await walk(path);
    else if (entry.name !== 'hashes.json') hashes.push({file:relative(root,path),sha256:hash(await readFile(path))});
  }
}
await walk(root);
await writeFile(join(root,'hashes.json'),JSON.stringify(hashes,null,2));
console.log(JSON.stringify({runs:runs.map(r=>({id:r.id,frames:r.stats.frames,fps:r.stats.measuredFps,maxIntervalMs:r.stats.maxIntervalMs})),pixelDiffs:pixelDiffs.map(d=>({theme:d.theme,count:d.count,bounds:d.bounds,underline:d.regions.underline.length,outside:d.regions.outside.length})),nativeReplayCheckpoints:nativeReplay.length,hashedFiles:hashes.length},null,2));
