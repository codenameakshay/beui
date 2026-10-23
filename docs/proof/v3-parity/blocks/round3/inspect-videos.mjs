import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const output = path.join(root, 'decoded-head');
await mkdir(output);
const manifest = JSON.parse(await readFile(path.join(root, 'labeled-head/manifest.json')));
const samples = [];
for (const video of manifest) {
  const lastInput = video.probes.length - 1;
  const start = video.probes.slice(0, lastInput).reduce((total, probe) => total + Number(probe.streams[0].nb_read_frames), 0);
  const size = Number(video.probes[lastInput].streams[0].nb_read_frames);
  const index = start + (video.name === 'glyph-readiness' ? Math.min(59, size - 1) : size - 1);
  const file = path.join(output, `${video.name}.png`);
  execFileSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', path.join(root, video.file), '-vf', `select=eq(n\\,${index})`, '-frames:v', '1', file]);
  samples.push({ name: video.name, file: path.relative(root, file), decodedFrameIndex: index, inputStart: start, sampleScope: 'One decoded final-input sample, not complete trajectory or cadence proof.' });
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(samples, null, 2));
