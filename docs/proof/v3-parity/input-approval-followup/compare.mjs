import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('./', import.meta.url));
const output = `${root}${process.argv[2] ?? 'crop-comparison'}`;
await mkdir(output);
const reference = `${root}../agents/round2/matched-crops/approval-card-reference.png`;
const timeline = JSON.parse(await readFile(`${root}candidate-capture/timeline.json`));
const candidate = `${root}candidate-capture/${timeline.frames.at(-1).file}`;
const run = args => {
  const result = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', ...args], {
    maxBuffer: 20 * 1024 * 1024,
  });
  assert.equal(result.status, 0, result.stderr.toString());
  return result.stdout;
};
run(['-i', candidate, '-vf', 'crop=512:421:464:265', '-frames:v', '1', `${output}/candidate.png`]);
const pixels = [reference, `${output}/candidate.png`].map(file =>
  run(['-i', file, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-frames:v', '1', 'pipe:1']));
assert.equal(pixels[0].length, 512 * 421 * 3);
assert.equal(pixels[1].length, pixels[0].length);
let changedPixels = 0;
let absoluteChannelDelta = 0;
for (let i = 0; i < pixels[0].length; i += 3) {
  if ([0, 1, 2].some(c => pixels[0][i + c] !== pixels[1][i + c])) changedPixels++;
  for (let c = 0; c < 3; c++) absoluteChannelDelta += Math.abs(pixels[0][i + c] - pixels[1][i + c]);
}
run(['-i', reference, '-i', `${output}/candidate.png`, '-filter_complex', 'blend=all_mode=difference', '-frames:v', '1', `${output}/difference.png`]);
const result = {
  width: 512, height: 421, candidateCrop: { x: 464, y: 265 },
  reference: 'agents/round2/matched-crops/approval-card-reference.png',
  referenceSha256: createHash('sha256').update(await readFile(reference)).digest('hex'),
  candidateFrame: timeline.frames.at(-1),
  changedPixels, totalPixels: 512 * 421, absoluteChannelDelta,
  verdict: changedPixels === 0 ? 'Exact crop match only' : 'FAIL. Nonzero pixel difference. No exact parity certification.',
  limitations: 'Historical source crop has unknown live revision. Top 421px only. Candidate uses unchanged defaultMono, not source default blue. Idle state only.',
};
await writeFile(`${output}/results.json`, JSON.stringify(result, null, 2));
console.log(JSON.stringify(result, null, 2));
