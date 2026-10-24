import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const root = 'docs/proof/v3-parity/charts/round4-candle-volume';
const [volumePhase = 'after-v9', output = 'native-state-review.json', candlePhase = 'after-v6'] = process.argv.slice(2);
const rows = [];
for (const chart of ['candle','volume']) {
  const phase = chart === 'candle' ? candlePhase : volumePhase;
  for (const preference of ['dark-no-preference','light-reduce']) {
    const source = JSON.parse(await readFile(`${root}/stills-source-v2-${chart}-${preference}/states.json`,'utf8'));
    const candidate = JSON.parse(await readFile(`${root}/stills-${phase}-${chart}-${preference}/states.json`,'utf8'));
    assert(candidate.scripts.some(script=>script.url.endsWith('main.dart.js')));
    for(const state of candidate.states) {
      const reference = source.states.find(item=>item.name===state.name);
      const valuesMatch = JSON.stringify(state.values) === JSON.stringify(reference.values);
      assert.equal(state.reduce,preference.endsWith('reduce'));
      assert.equal(state.probe.disableAnimations,state.reduce);
      assert(state.inputs.length && state.inputs.every(input=>input.isTrusted));
      assert.equal(state.canHover,!state.name.startsWith('touch-'));
      rows.push({chart,preference,state:state.name,sourceValues:reference.values,candidateValues:state.values,valuesMatch,sourceVisibleTooltipBoxes:reference.boxes.filter(box=>box.role==='tooltip'),candidateTooltipVisibility:'Inspect native PNG. Flutter compound-tooltip semantics do not expose a DOM tooltip role.',sourceImage:`stills-source-v2-${chart}-${preference}/${state.name}.png`,candidateImage:`stills-${phase}-${chart}-${preference}/${state.name}.png`});
    }
  }
}
const mismatches = rows.filter(row=>!row.valuesMatch);
await writeFile(`${root}/${output}`,JSON.stringify({checks:rows.length,valueMismatches:mismatches.length,rows},null,2),{flag:'wx'});
console.log(JSON.stringify({checks:rows.length,valueMismatches:mismatches},null,2));
if(mismatches.length) process.exitCode=1;
