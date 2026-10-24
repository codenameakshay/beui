import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const [left, right, name] = process.argv.slice(2);
const root = resolve('docs/proof/v3-parity/agents/round3');
const output = `${root}/${name}`;
await mkdir(output);
const records = await Promise.all([left, right].map(async run => JSON.parse(await readFile(`${root}/${run}/record.json`))));
const ffmpeg = args => {
  const result = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', ...args], { maxBuffer: 24 * 1024 * 1024 });
  assert.equal(result.status, 0, result.stderr.toString());
  return result.stdout;
};
const results = [];
for (const snapshot of records[0].snapshots) {
  const other = records[1].snapshots.find(s => s.state === snapshot.state);
  if (!other) continue;
  const { width, height } = snapshot.stage;
  assert.equal(other.stage.width, width);
  assert.equal(other.stage.height, height);
  const images = [snapshot, other].map((s, i) => {
    assert.equal(s.stage.x % 1, 0, 'fractional crop must be reviewed, not silently resampled');
    assert.equal(s.stage.y % 1, 0, 'fractional crop must be reviewed, not silently resampled');
    const size = JSON.parse(spawnSync('ffprobe', ['-v', 'error', '-show_streams', '-of', 'json', `${root}/${[left, right][i]}/${s.file}`], { encoding: 'utf8' }).stdout).streams[0];
    assert(s.stage.x >= 0 && s.stage.y >= 0 && s.stage.x + width <= size.width && s.stage.y + height <= size.height, 'crop exceeds the native raster');
    const path = `${output}/${i ? 'candidate' : 'source'}-${snapshot.state}.png`;
    ffmpeg(['-i', `${root}/${[left, right][i]}/${s.file}`, '-vf', `crop=${width}:${height}:${s.stage.x}:${s.stage.y}`, '-frames:v', '1', path]);
    return path;
  });
  const pixels = images.map(path => ffmpeg(['-i', path, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-frames:v', '1', 'pipe:1']));
  assert.equal(pixels[0].length, width * height * 3);
  assert.equal(pixels[1].length, pixels[0].length);
  const regions = [{ name: 'stage', x: 0, y: 0, width, height }];
  if (records[0].slug === 'file-diff') regions.push(
    { name: 'header', x: 0, y: 0, width, height: 36 },
    { name: 'body', x: 24, y: 42, width: width - 24, height: 138 },
  );
  if (records[0].slug === 'approval-card') regions.push(
    { name: 'options-first-question', x: 48, y: 48, width: width - 64, height: 128 },
    { name: 'replay', x: 0, y: height - 32, width: 120, height: 32 },
  );
  const metrics = regions.map(region => {
    let changedPixels = 0;
    let absoluteChannelDelta = 0;
    for (let y = region.y; y < region.y + region.height; y++) {
      for (let x = region.x; x < region.x + region.width; x++) {
        const offset = (y * width + x) * 3;
        if ([0, 1, 2].some(c => pixels[0][offset + c] !== pixels[1][offset + c])) changedPixels++;
        for (let c = 0; c < 3; c++) absoluteChannelDelta += Math.abs(pixels[0][offset + c] - pixels[1][offset + c]);
      }
    }
    return { ...region, changedPixels, totalPixels: region.width * region.height, absoluteChannelDelta };
  });
  ffmpeg(['-i', images[0], '-i', images[1], '-filter_complex', 'blend=all_mode=difference', '-frames:v', '1', `${output}/difference-${snapshot.state}.png`]);
  results.push({ state: snapshot.state, regions: metrics, verdict: metrics[0].changedPixels ? 'FAIL. Nonzero exact RGB difference.' : 'Exact static crop match only.', temporalEquivalence: false });
}
await writeFile(`${output}/results.json`, JSON.stringify({ inputs: [left, right], results }, null, 2));
console.log(JSON.stringify(results.map(r => ({ state: r.state, changed: r.regions[0].changedPixels, total: r.regions[0].totalPixels }))));
