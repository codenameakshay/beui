import assert from 'node:assert/strict';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('./', import.meta.url));
const run = process.argv[2] ?? 'matched-run2';
const output = `${root}${process.argv[3] ?? `${run}-comparison`}`;
await mkdir(output);
const records = JSON.parse(await readFile(`${root}${run}/records.json`));
const ffmpeg = args => {
  const result = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', ...args], { maxBuffer: 20 * 1024 * 1024 });
  assert.equal(result.status, 0, result.stderr.toString());
  return result.stdout;
};
const regions = [
  { name: 'full-preview', x: 0, y: 0, width: 512, height: 470 },
  { name: 'input-field', x: 50, y: 186, width: 444, height: 40 },
  { name: 'next-action', x: 464, y: 244, width: 32, height: 32 },
  { name: 'heading', x: 0, y: 0, width: 512, height: 48 },
  { name: 'options', x: 48, y: 48, width: 448, height: 128 },
  { name: 'replay', x: 0, y: 438, width: 120, height: 32 },
];
const results = [];
for (const state of ['idle', 'focus', 'text-entry']) {
  const paths = records.map(record => {
    const snapshot = record.snapshots.find(snapshot => snapshot.state === state);
    const { x, y, width, height } = snapshot.stage;
    const outputPath = `${output}/${record.phase}-${state}.png`;
    ffmpeg(['-i', `${root}${run}/${record.phase}/${snapshot.file}`, '-vf', `crop=${width}:${height}:${x}:${y}`, '-frames:v', '1', outputPath]);
    return outputPath;
  });
  const pixels = paths.map(path => ffmpeg(['-i', path, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-frames:v', '1', 'pipe:1']));
  for (const bytes of pixels) assert.equal(bytes.length, 512 * 470 * 3);
  ffmpeg(['-i', paths[0], '-i', paths[1], '-filter_complex', 'blend=all_mode=difference', '-frames:v', '1', `${output}/difference-${state}.png`]);
  const metrics = regions.map(region => {
    let changedPixels = 0;
    let absoluteChannelDelta = 0;
    for (let y = region.y; y < region.y + region.height; y++) {
      for (let x = region.x; x < region.x + region.width; x++) {
        const offset = (y * 512 + x) * 3;
        if ([0, 1, 2].some(c => pixels[0][offset + c] !== pixels[1][offset + c])) changedPixels++;
        for (let c = 0; c < 3; c++) absoluteChannelDelta += Math.abs(pixels[0][offset + c] - pixels[1][offset + c]);
      }
    }
    return { ...region, changedPixels, totalPixels: region.width * region.height, absoluteChannelDelta };
  });
  const sample = (phase, x, y) => [...pixels[phase].subarray((y * 512 + x) * 3, (y * 512 + x) * 3 + 3)];
  const caretColumns = pixels.map(bytes => {
    const columns = [];
    for (let x = 60; x < 400; x++) {
      let streak = 0;
      let maxStreak = 0;
      for (let y = 186; y < 226; y++) {
        const offset = (y * 512 + x) * 3;
        streak = [0, 1, 2].every(c => bytes[offset + c] >= 190) ? streak + 1 : 0;
        maxStreak = Math.max(streak, maxStreak);
      }
      if (maxStreak >= 16) columns.push({ x, maxStreak });
    }
    return columns;
  });
  results.push({ state, regions: metrics, caretColumns, fieldBackgroundSample: { x: 272, y: 189, source: sample(0, 272, 189), candidate: sample(1, 272, 189) }, verdict: metrics[0].changedPixels === 0 ? 'Exact crop match only' : 'FAIL. Nonzero pixel difference. No exact parity certification.' });
}
await writeFile(`${output}/results.json`, JSON.stringify(results, null, 2));
console.log(JSON.stringify(results, null, 2));
