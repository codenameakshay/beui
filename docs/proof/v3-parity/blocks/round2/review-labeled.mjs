import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const output = path.join(root, process.argv[2] || 'labeled-review');
await mkdir(output);
const manifest = JSON.parse(await readFile(path.join(root, process.argv[3] || 'labeled-final', 'manifest.json'), 'utf8'));
const results = [];
for (const item of manifest) {
  const frame = Number(item.beforeProbe.streams[0].nb_read_frames) + Math.min(30, Number(item.afterProbe.streams[0].nb_read_frames)-1);
  const destination = path.join(output, `${item.slug}-after.png`);
  const run = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', path.join(root, item.video), '-vf', `select=eq(n\\,${frame})`, '-frames:v', '1', destination], { encoding: 'utf8' });
  if (run.status !== 0) throw new Error(run.stderr);
  results.push({ video: item.video, decodedFrame: frame, png: path.relative(root, destination), method: 'Decode one existing video frame. No scaling or interpolation.' });
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(results, null, 2));
