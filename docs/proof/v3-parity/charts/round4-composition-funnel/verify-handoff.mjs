import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {readFile, writeFile} from 'node:fs/promises';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const readJson = async path => JSON.parse(await readFile(`${root}/${path}`));
const provenance = await readJson('build-provenance-quick-final.json');
for (const input of provenance.inputs) {
  assert.equal(hash(await readFile(input.path)), input.sha256, input.path);
  if (input.gitBlob !== null) assert.equal(execFileSync('git', ['rev-parse', `${provenance.revision}:${input.path}`], {encoding: 'utf8'}).trim(), input.gitBlob);
}
const response = await fetch('http://127.0.0.1:18116/main.dart.js');
assert.equal(response.status, 200);
assert.equal(hash(Buffer.from(await response.arrayBuffer())), provenance.candidateJavascriptSha256);
const native = await readJson('native-quick-final/states.json');
assert.equal(native.rows.length, 16);
const states = native.rows.flatMap(row => row.states);
assert.equal(states.length, 120);
assert.equal(states.filter(state => state.pass).length, 116);
const failures = native.rows.flatMap(row => row.states.filter(state => !state.pass).map(state => `${row.id} ${state.name}`));
assert.deepEqual(failures, [
  'candidate-funnel-chart-no-preference-mouse-keyboard click-dismiss',
  'candidate-funnel-chart-no-preference-touch tap-2',
  'candidate-funnel-chart-reduce-mouse-keyboard click-dismiss',
  'candidate-funnel-chart-reduce-touch tap-2',
]);
for (const row of native.rows) assert.equal(row.expectedHash, row.id.startsWith('source-') ? provenance.sourceJavascriptSha256 : provenance.candidateJavascriptSha256);
const pixels = await readJson('static-quick-final/measured-pixels.json');
const empty = await readJson('empty-native-v3/states.json');
assert.deepEqual(empty.rows.map(row => row.height), [256,148,148]);
const touch = await readJson('quick-touch-native-v2/states.json');
assert.equal(touch.length,8);
assert.equal(touch.flatMap(row=>row.states).length,56);
assert(touch.flatMap(row=>row.states).every(state=>state.pass));
assert.equal(pixels.length, 12);
const expected = [78640, 110984, 6717, 6341, 153923, 195412, 7780, 7296, 46498, 76612, 5901, 5009];
assert.deepEqual(pixels.map(row => row.diff.changedPixelsByMaxChannelThreshold['0']), expected);
for (const [file, pattern] of [
  ['owned-quick-final.log', /\+37: All tests passed!/],
  ['all-chart-quick-final.log', /\+220: All tests passed!/],
  ['analyze-quick-final.log', /No issues found!/],
  ['unchanged-goldens-quick-final.log', /\+15 -2: Some tests failed/],
  ['build-quick-final.log', /Built .*beui-round4-composition-funnel-quick-final-20261023/],
]) assert.match(await readFile(`${root}/${file}`, 'utf8'), pattern, file);
const result = {
  revision: provenance.revision,
  servedJavascriptSha256: provenance.candidateJavascriptSha256,
  focusedTests: 37,
  chartBehaviorTests: 220,
  analyzer: 'No issues',
  repeatedNativeTouch: {cases:8,passedStates:56,states:56},
  empty: empty.rows.map(row => ({dataCase:row.dataCase,height:row.height,changedPixels:row.changedPixels,meanError:row.meanAbsoluteChannelError})),
  unchangedGoldens: {passed: 15, failed: 2},
  native: {casesPassed: 12, cases: 16, statesPassed: 116, states: 120, failures},
  pixels: pixels.map(row => ({theme: row.theme, viewport: row.viewport.width, chart: row.slug, state: row.state, changed: row.diff.changedPixelsByMaxChannelThreshold['0'], meanError: row.diff.meanAbsoluteChannelError})),
  parity: 'NOT_CERTIFIED',
};
if (process.argv.includes('--record')) await writeFile(`${root}/handoff-gates-quick-final.json`, JSON.stringify(result, null, 2), {flag: 'wx'});
else assert.deepEqual(result, await readJson('handoff-gates-quick-final.json'));
console.log(JSON.stringify(result, null, 2));
