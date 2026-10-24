import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { spring } from '/tmp/beui-v3-parity-components-source/node_modules/motion-dom/dist/es/index.mjs';

const sourceRoot = '/tmp/beui-v3-parity-components-source';
const revision = 'a76e57c9bbc2837e96420b2610e9c82a3271bb05';
assert.equal(spawnSync('git', ['-C', sourceRoot, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).stdout.trim(), revision);
assert.equal(spawnSync('git', ['-C', sourceRoot, 'status', '--porcelain'], { encoding: 'utf8' }).stdout.trim(), '');
const runtimePath = `${sourceRoot}/node_modules/motion-dom/dist/es/animation/generators/spring.mjs`;
const physics = { stiffness: 700, damping: 50, mass: 0.5, restDelta: 0.001, restSpeed: 0.01 };
const segments = [];
let value = 0;
let velocity = 0;
for (const [target, times] of [
  [0.25, [16, 32, 80]],
  [0.75, [16, 48, 96]],
  [1, [16, 64, 160]],
  [0, [16, 80, 240, 640]],
  [0.6, [16, 80, 160]],
  [0, [16, 80, 640]],
]) {
  const generator = spring({ ...physics, keyframes: [value, target], velocity });
  const samples = times.map(timeMs => ({ timeMs, value: generator.next(timeMs).value, velocity: generator.velocity(timeMs) }));
  segments.push({ target, from: value, inheritedVelocity: velocity, samples });
  value = samples.at(-1).value;
  velocity = samples.at(-1).velocity;
}
const result = {
  sourceRevision: revision,
  runtime: JSON.parse(await readFile(`${sourceRoot}/node_modules/motion-dom/package.json`)).version,
  springRuntimeSha256: createHash('sha256').update(await readFile(runtimePath)).digest('hex'),
  physics,
  segments,
  scope: 'Analytical source spring and Flutter rendered silhouette under repeated retargets. Not native-frame material or synchronized browser equivalence.',
};
const output = process.argv[2];
assert(output, 'Choose a fresh output path. Existing evidence is never overwritten.');
await writeFile(output, JSON.stringify(result, null, 2), { flag: 'wx' });
console.log(JSON.stringify({ runtime: result.runtime, segments: segments.length, samples: segments.reduce((n, s) => n + s.samples.length, 0) }));
