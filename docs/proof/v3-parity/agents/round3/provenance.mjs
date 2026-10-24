import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';

const root = 'docs/proof/v3-parity/agents/round3';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const captured = hash(await readFile('example/build/agents-round3-after6/main.dart.js'));
const rebuilt = hash(await readFile('example/build/agents-round3-after7/main.dart.js'));
assert.equal(captured, rebuilt);
assert.equal(hash(await readFile(`${root}/frozen-javascript/final-main.dart.js`)), captured);
const sourceRoot = '/tmp/beui-v3-parity-components-source';
const command = (cmd, args) => {
  const result = spawnSync(cmd, args, { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
};
assert.equal(command('git', ['-C', sourceRoot, 'status', '--porcelain']), '');
const sourceRevision = command('git', ['-C', sourceRoot, 'rev-parse', 'HEAD']);
assert.equal(sourceRevision, 'a76e57c9bbc2837e96420b2610e9c82a3271bb05');
const paths = command('git', ['diff', '--name-only', 'a2942181', '--', 'lib', 'example/lib', 'test']).split('\n');
const inputs = await Promise.all(paths.map(async path => ({ path, sha256: hash(await readFile(path)) })));
const result = {
  base: 'a2942181',
  codeHead: command('git', ['rev-parse', 'HEAD']),
  sourceRevision,
  sourceClean: true,
  liveRevision: 'unknown',
  capturedBuild: 'agents-round3-after6',
  postCommitBuild: 'agents-round3-after7',
  browserLoadedJsSha256: captured,
  postCommitRebuildJsSha256: rebuilt,
  capturedAndRebuiltBytesIdentical: true,
  inputs,
  palette: 'source-default-a76e57c9',
  onlyBoundPort: 18117,
  parentChangesNotAdopted: ['ea2024e3', 'e81e9cc2'],
  unrelatedDirtyFileExcluded: 'example/analysis_options.yaml',
};
await writeFile(process.argv[2], JSON.stringify(result, null, 2), { flag: 'wx' });
console.log(JSON.stringify({ codeHead: result.codeHead, capturedAndRebuiltBytesIdentical: true, sha256: captured, sourceRevision }));
