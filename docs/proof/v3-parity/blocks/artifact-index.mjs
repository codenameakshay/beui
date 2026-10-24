import { readdir, readFile, stat, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
async function walk(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...await walk(file));
    else result.push(file);
  }
  return result;
}

const videos = [];
for (const file of await walk(root)) {
  if (!['mount.webm', 'interaction.webm', 'capture.mp4'].includes(path.basename(file)) && !file.includes('/change-videos')) continue;
  if (!/\.(webm|mp4)$/.test(file)) continue;
  const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,r_frame_rate,avg_frame_rate,nb_read_frames:format=duration', '-of', 'json', file], { encoding: 'utf8' }));
  videos.push({
    path: path.relative(root, file),
    sha256: createHash('sha256').update(await readFile(file)).digest('hex'),
    bytes: (await stat(file)).size,
    stream: probe.streams[0],
    durationSeconds: Number(probe.format.duration),
    verdict: file.includes('/after-width592') ? 'invalid foreign build' : 'inconclusive',
  });
}
const index = JSON.stringify({ baseline: '5ec78ac30e1274727ddd185a883346e4d908e6c8', sourceCheckout: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', liveDeploymentRevision: null, videos }, null, 2);
if (process.argv[2]) await writeFile(path.resolve(process.argv[2]), index);
else console.log(index);
