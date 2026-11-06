import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import path from 'node:path';
import vm from 'node:vm';

const source = process.argv[2] || '/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/source-1ab921e6';
const revision = '1ab921e62283e788a686bc4bafa1de5ff56104ea';
assert.equal(execFileSync('git', ['rev-parse', 'HEAD'], { cwd: source, encoding: 'utf8' }).trim(), revision);
const files = ['components/motion/mines.tsx', 'components/motion/plinko.tsx'];
const [mines, plinko] = files.map(file => readFileSync(path.join(source, file), 'utf8'));
const between = (text, start, end) => {
  const from = text.indexOf(start);
  const to = end ? text.indexOf(end, from) : text.length;
  assert(from >= 0 && to > from, `Missing extraction anchors ${start}, ${end}`);
  return text.slice(from, to);
};
const code = [
  between(mines, 'export function minesMultiplier', '// Revealed icons'),
  between(mines, 'const SHORT =', null),
  between(plinko, 'export function plinkoSlots', '/** An icon button'),
].join('\n');
const api = vm.runInNewContext(`${stripTypeScriptTypes(code).replace(/\bexport /g, '')}\n({minesMultiplier, formatMultiplier, plinkoSlots})`, {}, { timeout: 1000 });
const multiplierInputs = [[25, 3, 0], [25, 3, 1], [25, 3, 2], [25, 3, 22], [4, 1, 3], [4, 99, 1], [4, -1, 8], [25, 3, -2]];
const formatInputs = [1, 2.5, 9999.99, 10000, 5200000, 1.3e29];
const slotInputs = [{ rows: 8 }, { rows: 8, options: { center: 0.5, edge: 10 } }, { rows: 12 }, { rows: 16 }, { rows: 1 }, { rows: 0 }, { rows: 8, options: { center: 0, edge: -1 } }];
const result = {
  schema: 1, sourceRevision: revision,
  sourceFiles: files.map((file, index) => ({ path: file, sha256: createHash('sha256').update([mines, plinko][index]).digest('hex') })),
  method: 'Execute the exact pinned exported pure helper bodies in an isolated VM. No JSX, game rendering, or copied helper implementation is involved.',
  minesMultiplier: multiplierInputs.map(args => ({ args, expected: api.minesMultiplier(...args) })),
  formatMultiplier: formatInputs.map(value => ({ value, expected: api.formatMultiplier(value) })),
  plinkoSlots: slotInputs.map(input => ({ ...input, expected: Array.from(api.plinkoSlots(input.rows, input.options)) })),
};
assert.deepEqual(result.plinkoSlots[1].expected, [10, 5, 2, 1, 0.5, 1, 2, 5, 10]);
assert.equal(result.minesMultiplier[4].expected, 4);
const output = path.resolve('test/fixtures/blocks/source_contracts.json');
mkdirSync(path.dirname(output), { recursive: true });
writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify({ output, multiplierCases: result.minesMultiplier.length, formattingCases: result.formatMultiplier.length, slotCases: result.plinkoSlots.length }));
