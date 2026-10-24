import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFile, writeFile} from 'node:fs/promises';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const base = 'a2942181';
const {revision} = JSON.parse(await readFile(`${root}/build-provenance-quick-final.json`));
const expected = [
  'lib/src/charts/composition_chart.dart',
  'lib/src/charts/funnel_chart.dart',
  'test/charts/composition_chart_test.dart',
  'test/charts/composition_funnel_round4_test.dart',
  'test/charts/funnel_chart_test.dart',
];
const paths = execFileSync('git', ['diff', '--name-only', base, revision], {encoding: 'utf8'}).trim().split('\n');
assert.deepEqual(paths.sort(), expected.sort());
assert.equal(execFileSync('git', ['diff', '--name-only'], {encoding: 'utf8'}), '');
execFileSync('git', ['diff', '--check', base, revision]);
const result = {
  base,
  revision,
  paths,
  sharedAndOriginalTrackedInputsUnchanged: true,
  independentReview: 'Not performed. Children explicitly prohibited.',
  manualCommentReview: 'Two added public API doc comments. No added inline application comments or suppressions.',
};
if (process.argv.includes('--record')) await writeFile(`${root}/scope-quick-final.json`, JSON.stringify(result, null, 2), {flag: 'wx'});
else assert.deepEqual(result, JSON.parse(await readFile(`${root}/scope-quick-final.json`)));
console.log(JSON.stringify(result, null, 2));
