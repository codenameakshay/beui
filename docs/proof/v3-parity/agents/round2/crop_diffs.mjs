import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('./', import.meta.url));
const output = `${root}matched-crops`;
await mkdir(output);
const result = [];
const run = args => {
  const process = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', ...args], { maxBuffer: 20 * 1024 * 1024 });
  assert.equal(process.status, 0, process.stderr.toString());
  return process.stdout;
};
for (const item of [
  { slug: 'approval-card', width: 512, height: 421, source: { x: 424, y: 492 }, candidate: { x: 464, y: 265 }, state: 'Initial question. Source stage bottom 49px clipped. Compare the same top 421px only.' },
  { slug: 'file-diff', width: 512, height: 300, source: { x: 424, y: 384 }, candidate: { x: 464, y: 350 }, state: 'Settled auto-collapsed header and Replay. Does not prove streamed row geometry.' },
]) {
  const paths = [];
  const pixels = [];
  for (const phase of ['reference', 'handoff']) {
    const timeline = JSON.parse(await readFile(`${root}${phase}/${item.slug}/timeline.json`));
    const frame = phase === 'reference' && item.slug === 'approval-card' ? timeline.frames[0] : timeline.frames.at(-1);
    const input = `${root}${phase}/${item.slug}/${frame.file}`;
    const bounds = phase === 'reference' ? item.source : item.candidate;
    const crop = `crop=${item.width}:${item.height}:${bounds.x}:${bounds.y}`;
    const file = `${output}/${item.slug}-${phase}.png`;
    run(['-i', input, '-vf', crop, '-frames:v', '1', file]);
    pixels.push(run(['-i', file, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-frames:v', '1', 'pipe:1']));
    paths.push(file);
  }
  assert.equal(pixels[0].length, pixels[1].length);
  let changed = 0;
  let absoluteDelta = 0;
  for (let i = 0; i < pixels[0].length; i += 3) {
    if (pixels[0][i] !== pixels[1][i] || pixels[0][i + 1] !== pixels[1][i + 1] || pixels[0][i + 2] !== pixels[1][i + 2]) changed++;
    for (let c = 0; c < 3; c++) absoluteDelta += Math.abs(pixels[0][i + c] - pixels[1][i + c]);
  }
  run(['-i', paths[0], '-i', paths[1], '-filter_complex', 'blend=all_mode=difference', '-frames:v', '1', `${output}/${item.slug}-difference.png`]);
  result.push({ ...item, changedPixels: changed, totalPixels: item.width * item.height, absoluteChannelDelta: absoluteDelta, verdict: changed === 0 ? 'Exact crop match only' : 'FAIL. Nonzero pixel difference. No exact parity certification.' });
}
await writeFile(`${output}/results.json`, JSON.stringify(result, null, 2));
console.log(JSON.stringify(result, null, 2));
