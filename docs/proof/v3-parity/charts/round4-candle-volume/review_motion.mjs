import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const root='docs/proof/v3-parity/charts/round4-candle-volume';
const rows=[];
for(const chart of ['candle','volume'])for(const preference of ['dark-no-preference','light-reduce'])for(const touch of [false,true]){
  const suffix=`${chart}-${preference}${touch?'-touch':''}`;
  const reference=JSON.parse(await readFile(`${root}/source-${suffix}/observations.json`,'utf8'));
  const candidate=JSON.parse(await readFile(`${root}/after-v13-${suffix}/observations.json`,'utf8'));
  assert.equal(candidate.length,reference.length,suffix);
  for(let i=0;i<candidate.length;i++){
    assert.equal(candidate[i].action,reference[i].action,suffix);
    assert.deepEqual(candidate[i].values,reference[i].values,`${suffix} ${i}`);
    const bootstrap=candidate[i].inputs.filter(input=>!input.isTrusted);
    assert.equal(bootstrap.length,1,suffix);
    assert.deepEqual(bootstrap[0],{type:'click',pointerType:'',isTrusted:false,x:0,y:0},suffix);
    const native=candidate[i].inputs.filter(input=>input.isTrusted);
    assert(native.length && native.some(input=>input.type==='pointerdown'),suffix);
    if(touch)assert(candidate[i].inputs.some(input=>input.pointerType==='touch'),suffix);
  }
  const timeline=JSON.parse(await readFile(`${root}/after-v13-${suffix}/timeline.json`,'utf8'));
  rows.push({suffix,actions:candidate.length,valuesMatch:true,trustedActions:true,syntheticBootstrap:'One zero-coordinate click enables Flutter semantics before the native action timeline.',originalFrames:timeline.frames.length,fps:timeline.stats.measuredFps,maxGapMs:timeline.stats.maxIntervalMs,motionVerdict:timeline.stats.fastMotionVerdict});
}
await writeFile(`${root}/native-motion-review-v13.json`,JSON.stringify({rows},null,2),{flag:'wx'});
console.log(JSON.stringify(rows,null,2));
