import assert from 'node:assert/strict';
import {build} from '/tmp/beui-charts-fixture-runtime-20261023/node_modules/esbuild/lib/main.js';
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const path = '/tmp/beui-charts-reference-20261023/components/charts/funnel-chart/model.ts';
const bytes = await readFile(path);
const output = await build({entryPoints: [path], bundle: true, format: 'esm', write: false});
const {buildFunnel, funnelPath} = await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].contents).toString('base64')}`);
const pathological = buildFunnel([
  {id: 'a', label: 'Invalid', value: NaN},
  {id: 'a', label: 'Zero', value: 0},
  {id: 'a', label: 'Repeated', value: 5},
  {id: 'b', label: 'Large', value: 100},
  {id: 'c', label: 'Negative', value: -1},
  {id: 'd', label: 'Infinite', value: Infinity},
]);
assert.deepEqual(pathological.rows.map(({label, proportion, conversion, stepConversion, change}) => ({label, proportion, conversion, stepConversion, change})), [
  {label: 'Zero', proportion: 0, conversion: null, stepConversion: null, change: null},
  {label: 'Large', proportion: 1, conversion: null, stepConversion: null, change: 100},
]);
assert.deepEqual(buildFunnel([]).rows, []);
assert.deepEqual(buildFunnel([{id: 'a', label: 'A', value: 100}, {id: 'b', label: 'B', value: 200}]).rows.map(row => row.conversion), [100, 200]);
const extremes = [0, 1.005, 9.995, 1e-308, 1e308].map(value => ({value, formatted: value.toLocaleString('en-US', {maximumFractionDigits: 2})}));
assert.deepEqual(extremes.slice(0, 4).map(row => row.formatted), ['0', '1.01', '10', '0']);
assert.equal(extremes[4].formatted.replaceAll(',', ''), `1${'0'.repeat(308)}`);
await writeFile(`${root}/source-model-results.json`, JSON.stringify({pinnedSource: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', path, sha256: createHash('sha256').update(bytes).digest('hex'), pathological, extremes, paths: ['vertical', 'horizontal'].map(direction => ({direction, paths: [0, 1, 2].map(i => funnelPath([1, .2, .8], i, direction))})), passed: true}, null, 2), {flag: 'wx'});
console.log('Pinned-source funnel pathological-data and formatting checks passed.');
