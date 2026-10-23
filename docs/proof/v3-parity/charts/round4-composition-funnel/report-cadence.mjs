import assert from 'node:assert/strict';
import {readdir, readFile, writeFile} from 'node:fs/promises';
import {join} from 'node:path';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const phase = process.argv[2] ?? 'final-v4';
const recordings = [];
for (const batch of [`captures-${phase}`, `captures-input-${phase}`]) {
  for (const entry of await readdir(join(root, batch), {withFileTypes: true})) {
    if (!entry.isDirectory()) continue;
    const directory = join(batch, entry.name);
    const timeline = JSON.parse(await readFile(join(root, directory, 'timeline.json')));
    assert.equal(timeline.stats.errors.length, 0, directory);
    recordings.push({directory, ...timeline.stats});
  }
}
const result = {
  recordings,
  minFps: Math.min(...recordings.map(recording => recording.measuredFps)),
  maxFps: Math.max(...recordings.map(recording => recording.measuredFps)),
  maxIntervalMs: Math.max(...recordings.map(recording => recording.maxIntervalMs)),
  verdict: 'Inconclusive for short motion trajectories. Original exposure intervals remain authoritative.',
};
await writeFile(join(root, `cadence-${phase}.json`), JSON.stringify(result, null, 2), {flag: 'wx'});
console.log(JSON.stringify(result, null, 2));
