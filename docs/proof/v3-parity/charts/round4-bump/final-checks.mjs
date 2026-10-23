import {readFile,writeFile,mkdir,copyFile,constants} from 'node:fs/promises';
import assert from 'node:assert/strict';
const root='docs/proof/v3-parity/charts/round4-bump';
const read=async path=>JSON.parse(await readFile(`${root}/${path}`));
const inputs=await read('build-inputs-v12.json');
const results=[];
for(const side of ['source','after']){
  const states=await read(`repeat-${side}-v2/states.json`);
  assert.equal(states.length,28);
  const build=inputs.builds.find(x=>x.side===side);
  for(const reducedMotion of ['no-preference','reduce']){
    const report=await read(`repeat-${side}-v2/${reducedMotion}-events.json`);
    assert(report.scripts.some(x=>x.sha256===build.sha256));
    assert(report.keys.every(x=>x.isTrusted));
    assert.equal(report.keys.filter(x=>x.type==='keydown'&&x.key==='Enter'&&x.repeat).length,2);
  }
  if(side==='after')for(const state of states){
    assert.equal(state.flutter.disableAnimations,state.reducedMotion==='reduce');
    assert.equal(state.flutter.platformDisableAnimations,state.reducedMotion==='reduce');
  }
  results.push({side,states:states.length,path:`repeat-${side}-v2/states.json`,servedJs:build.sha256,repeatAndKeyupAssertions:true});
}
await mkdir(`${root}/golden-failure-v12`);
for(const name of ['masterImage','testImage','maskedDiff','isolatedDiff']){
  const file=`beui_bump_chart_${name}.png`;
  await copyFile(`test/charts/failures/${file}`,`${root}/golden-failure-v12/${file}`,constants.COPYFILE_EXCL);
}
await writeFile(`${root}/repeat-summary.json`,JSON.stringify({verified:true,results},null,2),{flag:'wx'});
console.log(JSON.stringify({verified:true,results,goldenFeedback:'Four unchanged Flutter failure feedback PNGs copied exclusively into golden-failure-v12.'},null,2));
