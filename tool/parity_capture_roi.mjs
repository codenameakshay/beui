#!/usr/bin/env node
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';

const [referenceArg, candidateArg, outputArg, referenceCrop, candidateCrop] = process.argv.slice(2);
if (!candidateCrop) throw new Error('Usage: node tool/parity_capture_roi.mjs REFERENCE_RUN CANDIDATE_RUN NEW_DIR REF_X:Y:W:H CAND_X:Y:W:H');
const output = resolve(outputArg);
const runs = await Promise.all([referenceArg, candidateArg].map(async arg => {
  const directory = resolve(arg);
  const timeline = JSON.parse(await readFile(join(directory, 'timeline.json'), 'utf8'));
  if (!Number.isFinite(timeline.stats.originEpochMs)) throw new Error('Run lacks epoch clock anchor');
  const first = timeline.events[0];
  const eventMs = (first.dispatchBeforeMs + first.dispatchAfterMs) / 2;
  return { directory, timeline, frames: timeline.frames.map(frame => ({ ...frame,
    relativeMs: (frame.requestedMs === undefined
      ? frame.metadata.timestamp * 1000 - timeline.stats.originEpochMs
      : (frame.requestedMs + frame.receivedMs) / 2) - eventMs,
  })) };
}));
const crops = [referenceCrop, candidateCrop].map(text => {
  const values = text.split(':').map(Number);
  if (values.length !== 4 || values.some(v => !Number.isInteger(v) || v < 0) || !values[2] || !values[3]) throw new Error('Invalid crop');
  return values;
});
if (crops[0][2] !== crops[1][2] || crops[0][3] !== crops[1][3]) throw new Error('Crops must have identical dimensions');
for (const [side, run] of runs.entries()) {
  const header = await readFile(join(run.directory, run.frames[0].file));
  const [x, y, width, height] = crops[side];
  if (x + width > header.readUInt32BE(16) || y + height > header.readUInt32BE(20)) throw new Error('Crop exceeds original PNG dimensions');
}
await mkdir(output);
for (const name of ['reference', 'candidate']) await mkdir(join(output, name));
const used = [new Set(), new Set()];
const selected = [];
const omitted = [];
for (let timeMs = -300; timeMs <= 3200; timeMs += 100) {
  const pair = runs.map(run => run.frames.reduce((best, frame) =>
    Math.abs(frame.relativeMs - timeMs) < Math.abs(best.relativeMs - timeMs) ? frame : best));
  if (pair.some((frame, side) => used[side].has(frame.index) || Math.abs(frame.relativeMs - timeMs) > 49)) {
    omitted.push(timeMs);
    continue;
  }
  pair.forEach((frame, side) => {
    used[side].add(frame.index);
    const [x, y, width, height] = crops[side];
    const result = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', join(runs[side].directory, frame.file),
      '-vf', `crop=${width}:${height}:${x}:${y}`, '-frames:v', '1',
      join(output, side ? 'candidate' : 'reference', `frame_${String(selected.length).padStart(4, '0')}.png`)], { encoding: 'utf8' });
    if (result.status !== 0) throw new Error(result.stderr);
  });
  selected.push({ requestedRelativeMs: timeMs, frames: pair });
}
if (selected.length < 2) throw new Error('Insufficient paired samples');
const result = { reference: resolve(referenceArg), candidate: resolve(candidateArg), crops,
  nominalGridMs: 100, maximumNearestSampleErrorMs: 49, omittedGridTimesMs: omitted,
  verdict: 'diagnostic only; missing intervals and exposure uncertainty prevent exact timing verdict', selected };
await writeFile(join(output, 'selection.json'), JSON.stringify(result, null, 2));
console.log(JSON.stringify({ selected: selected.length, omitted, output }));
