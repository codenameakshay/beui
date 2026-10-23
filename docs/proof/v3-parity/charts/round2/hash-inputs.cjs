const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const source = '/tmp/beui-charts-reference-20261023';
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const inventory = JSON.parse(fs.readFileSync('docs/proof/v3-parity/audit/inventory.json'));
const rows = inventory.rows.filter(row => row.family === 'charts');
const changed = cp.execFileSync('git', ['diff', 'b3308ad', '--name-only', '--', 'lib/src/charts', 'example/lib/demos', 'test/charts'], {encoding: 'utf8'}).trim().split('\n').filter(Boolean);
changed.push('test/charts/chart_round2_test.dart');
console.log(JSON.stringify({
  baseline: '5ec78ac30e1274727ddd185a883346e4d908e6c8',
  round2Base: cp.execFileSync('git', ['rev-parse', 'b3308ad'], {encoding: 'utf8'}).trim(),
  implementationHead: cp.execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(),
  source: cp.execFileSync('git', ['-C', source, 'rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(),
  sourceDirty: cp.execFileSync('git', ['-C', source, 'status', '--porcelain'], {encoding: 'utf8'}),
  candidate: [...new Set(changed)].map(file => ({file, sha256: hash(file)})),
  sourcePreviews: rows.flatMap(row => row.sourcePreviewCandidates).map(file => ({file, sha256: hash(path.join(source, file))})),
  environment: {os: cp.execFileSync('sw_vers', [], {encoding: 'utf8'}).trim(), flutter: cp.execFileSync('flutter', ['--version'], {encoding: 'utf8'}).trim()},
}, null, 2));
