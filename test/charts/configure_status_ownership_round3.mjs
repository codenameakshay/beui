import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const root = 'docs/proof/v3-parity/charts/round3';
const output = process.argv[2];
const sha = async path => createHash('sha256').update(await readFile(path)).digest('hex');
await mkdir(output);
for (const source of [true, false]) {
  for (const [theme, reducedMotion] of [['dark', 'no-preference'], ['light', 'reduce']]) {
    const base = JSON.parse(await readFile(`${root}/configs-final-v10/after-status-bar-${theme}-${reducedMotion}.json`));
    const script = source ? 'source/source.js' : 'main.dart.js';
    base.url = `http://127.0.0.1:8109/${source ? 'source/' : ''}?theme=${theme}`;
    base.reference = false;
    base.requireFlutterProbe = !source;
    base.servedJs = {
      url: `http://127.0.0.1:8109/${script}`,
      sha256: await sha(`/tmp/beui-charts-round3-status-fixture-v2-20261023/${script}`),
      revision: source ? 'a76e57c9bbc2837e96420b2610e9c82a3271bb05 plus isolated ownership fixture' : '1a9fa600 plus dc7d3332 chart behavior and shared dependencies',
    };
    base.provenance.fixtureSource = source;
    base.provenance.fixtureRevision = '1a9fa600';
    base.provenance.fixtureScope = 'Behavior-only wrapper. Exact source chart and Tooltip imports, not a source pixel baseline. No inspector blur or direct state/focus injection.';
    base.provenance.keyboardMethod = 'Actual native Tab/R/I/ArrowRight/Escape. R/I update only the consumer data list.';
    base.provenance.revision = base.servedJs.revision;
    base.targets = {};
    base.events = [
      {atMs: 300, type: 'key', key: 'Tab', caption: 'Native Tab focuses Tuesday and opens its readout.'},
      {atMs: 1100, type: 'key', key: 'r', caption: 'Remove Tuesday while the inspector retains focus.'},
      {atMs: 1900, type: 'key', key: 'i', caption: 'Reinsert Tuesday. Its stale tooltip must not revive.'},
      {atMs: 2700, type: 'key', key: 'ArrowRight', caption: 'Explicit native keyboard inspection reopens Tuesday.'},
      {atMs: 3400, type: 'key', key: 'Escape', caption: 'Native Escape dismisses without losing focus.'},
    ];
    base.finalHoldMs = 500;
    await writeFile(`${output}/${source ? 'source' : 'after'}-status-bar-identity-${theme}-${reducedMotion}.json`, JSON.stringify(base, null, 2), {flag: 'wx'});
  }
}
