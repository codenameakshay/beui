import assert from 'node:assert/strict';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const output = path.join(root, 'decoded-held');
await mkdir(output);
const videos = JSON.parse(await readFile(path.join(root, 'labeled-hold750/manifest.json')));
const samples = [];
for (const video of videos) {
  for (let input = 0; input < video.inputs.length; input++) {
    const timeline = JSON.parse(await readFile(path.join(root, path.dirname(video.inputs[input]), 'timeline.json')));
    const start = video.probes.slice(0, input).reduce((sum, probe) => sum + Number(probe.streams[0].nb_read_frames), 0);
    for (const [state, atMs] of [['held', 1400], ['released', 2200], ['keyboard', 3100]]) {
      if (input === 0 && video.name === 'privacy-hold750-dark' && state === 'keyboard') continue;
      const frame = timeline.frames.findIndex(frame => frame.requestedMs >= timeline.stats.sequenceStartMs + atMs);
      assert(frame >= 0);
      const index = start + frame;
      const file = path.join(output, `${video.name}-${input}-${state}.png`);
      execFileSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', path.join(root, video.file), '-vf', `select=eq(n\\,${index})`, '-frames:v', '1', file]);
      samples.push({ video: video.file, input: video.inputs[input], state, file: path.relative(root, file), decodedFrameIndex: index,
        requestedRelativeMs: atMs, originalFrame: timeline.frames[frame], limitation: 'Existing captured sample only. No interpolation or complete motion timing verdict.' });
    }
  }
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(samples, null, 2));
