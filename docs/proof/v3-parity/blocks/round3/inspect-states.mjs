import assert from 'node:assert/strict';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const output = path.join(root, 'decoded-states');
await mkdir(output);
const videos = JSON.parse(await readFile(path.join(root, 'labeled-head/manifest.json')));
const samples = [];
for (const [name, states] of [
  ['controls-dark', [['held-action', 1300], ['keyboard-action', 2900]]],
  ['controls-light-reduced', [['held-action', 1300], ['keyboard-action', 2900]]],
  ['card-privacy-dark', [['revealed', 1100]]],
  ['card-source-light-reduced', [['revealed', 1100]]],
]) {
  const video = videos.find(video => video.name === name);
  assert(video);
  const lastInput = video.inputs.length - 1;
  const timeline = JSON.parse(await readFile(path.join(root, path.dirname(video.inputs[lastInput]), 'timeline.json')));
  const start = video.probes.slice(0, lastInput).reduce((sum, probe) => sum + Number(probe.streams[0].nb_read_frames), 0);
  for (const [state, atMs] of states) {
    const frame = timeline.frames.findIndex(frame => frame.requestedMs >= timeline.stats.sequenceStartMs + atMs);
    assert(frame >= 0);
    const index = start + frame;
    const file = path.join(output, `${name}-${state}.png`);
    execFileSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', path.join(root, video.file), '-vf', `select=eq(n\\,${index})`, '-frames:v', '1', file]);
    samples.push({ name, state, file: path.relative(root, file), video: video.file, decodedFrameIndex: index, requestedRelativeMs: atMs,
      originalFrame: timeline.frames[frame], limitation: 'Existing captured sample only. No synthesized intermediate frame or motion timing verdict.' });
  }
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(samples, null, 2));
