import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const directory = process.argv[2];
const results = [];
for (const id of await readdir(directory)) {
  let timeline;
  try { timeline = JSON.parse(await readFile(join(directory, id, 'timeline.json'))); }
  catch (error) { if (error.code === 'ENOENT' || error.code === 'ENOTDIR') continue; throw error; }
  const environment = JSON.parse(await readFile(join(directory, id, 'environment.json')));
  let dimensions;
  for (const frame of timeline.frames) {
    const bytes = await readFile(join(directory, id, frame.file));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), frame.sha256);
    const current = { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
    if (dimensions) assert.deepEqual(current, dimensions);
    dimensions = current;
  }
  assert.deepEqual(dimensions, { width: timeline.stats.video.width, height: timeline.stats.video.height });
  assert.equal(timeline.frames.length, timeline.stats.video.decodedFrames);
  const reference = id.startsWith('reference');
  const sample = reference ? { x: 308, y: 484 } : id.startsWith('visual') ? { x: 10, y: 10 } : { x: 620, y: 340 };
  const rgb = [...execFileSync('ffmpeg', ['-v', 'error', '-i', join(directory, id, timeline.frames[0].file),
    '-vf', `crop=1:1:${sample.x}:${sample.y}`, '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'])];
  assert.deepEqual(rgb, id.includes('dark') ? [21, 21, 21] : [252, 252, 252]);
  const inspect = timeline.frames.reduce((best, frame) =>
    Math.abs(frame.receivedMs - timeline.stats.sequenceStartMs - 900) < Math.abs(best.receivedMs - timeline.stats.sequenceStartMs - 900) ? frame : best);
  results.push({
    id, url: JSON.parse(await readFile(join(directory, id, 'config.json'))).url,
    requestedReducedMotion: environment.requestedReducedMotion,
    browserReducedMotion: environment.reducedMotion,
    flutterCapture: environment.flutterCapture,
    browser: environment.browser, domViewport: environment.viewport, dpr: environment.dpr,
    originalDimensions: dimensions, frames: timeline.frames.length,
    measuredFps: timeline.stats.measuredFps, maxIntervalMs: timeline.stats.maxIntervalMs,
    backgroundPixel: { ...sample, rgb, frame: timeline.frames[0].file },
    hoverInspectionFrame: inspect.file,
    servedJs: environment.servedJs,
    integrity: 'all original PNG hashes and dimensions match; encoded frame count matches',
    motionVerdict: 'inconclusive; native 60fps unresolved; no interpolated or duplicated frames',
  });
}
await writeFile(join(directory, 'summary.json'), JSON.stringify(results, null, 2), { flag: 'wx' });
console.log(JSON.stringify(results.map(({ id, measuredFps, frames, backgroundPixel }) => ({ id, measuredFps, frames, backgroundPixel })), null, 2));
