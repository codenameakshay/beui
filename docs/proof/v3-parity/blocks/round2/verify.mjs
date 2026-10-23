import { readdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const timelines = [];
async function walk(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory() && entry.name !== 'original-frames') await walk(file);
    else if (entry.name === 'timeline.json') timelines.push(file);
  }
}
await walk(root);
const runs = [];
for (const file of timelines.sort()) {
  const directory = path.dirname(file);
  const timeline = JSON.parse(await readFile(file, 'utf8'));
  for (const frame of timeline.frames) {
    const actual = createHash('sha256').update(await readFile(path.join(directory, frame.file))).digest('hex');
    if (actual !== frame.sha256) throw new Error(`Changed original ${directory}/${frame.file}`);
    if (!(frame.receivedMs >= frame.requestedMs)) throw new Error(`Invalid request-response interval ${directory}`);
  }
  const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_read_frames:format=duration', '-of', 'json', path.join(directory, 'capture.mp4')], { encoding: 'utf8' }));
  if (Number(probe.streams[0].nb_read_frames) !== timeline.frames.length) throw new Error(`Frame loss ${directory}`);
  const environment = JSON.parse(await readFile(path.join(directory, 'environment.json'), 'utf8'));
  runs.push({ directory: path.relative(root, directory), pngHashesVerified: timeline.frames.length, probe,
    measuredFps: timeline.stats.measuredFps, maxIntervalMs: timeline.stats.maxIntervalMs, events: timeline.events.length,
    dispatchErrors: timeline.events.filter(e => e.error), effectiveFlutter: environment.flutterCapture ?? null,
    requestedReducedMotion: environment.requestedReducedMotion ?? 'not observed', verdict: 'Fast motion inconclusive. No exact image, native application or 60 FPS certification.' });
}
const before = execFileSync('shasum', ['-a', '256', '-c', path.join(root, '../before-sha256.txt')], { cwd: path.resolve(root, '../../../../..'), encoding: 'utf8' });
const original = JSON.parse(await readFile(path.join(root, '../verification.json'), 'utf8'));
const labeled = [];
for (const directory of ['labeled', 'labeled-final', 'labeled-press']) {
  labeled.push(...JSON.parse(await readFile(path.join(root, directory, 'manifest.json'), 'utf8')));
}
for (const item of labeled) {
  const file = path.join(root, item.video);
  const actual = createHash('sha256').update(await readFile(file)).digest('hex');
  if (actual !== item.sha256) throw new Error(`Changed labeled video ${item.video}`);
  const frames = Number(execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=nb_read_frames', '-of', 'csv=p=0', file], { encoding: 'utf8' }).trim());
  if (frames !== item.inputFrames) throw new Error(`Changed labeled frame count ${item.video}`);
}
let originalPngsVerified = 0;
for (const run of original.runs) {
  const directory = path.join(root, '..', run.path);
  const timeline = JSON.parse(await readFile(path.join(directory, 'timeline.json'), 'utf8'));
  for (const frame of timeline.frames) {
    const actual = createHash('sha256').update(await readFile(path.join(directory, frame.file))).digest('hex');
    if (actual !== frame.sha256) throw new Error(`Changed round1 original ${directory}/${frame.file}`);
    originalPngsVerified++;
  }
}
const pressRest = [];
for (const theme of ['dark', 'light']) {
  const files = ['press-before', 'press-after'].map(batch => `${batch}/candidate-${theme}-no-preference-rest.png`);
  const hashes = await Promise.all(files.map(async file => createHash('sha256').update(await readFile(path.join(root, file))).digest('hex')));
  if (hashes[0] !== hashes[1]) throw new Error(`Press fix changed rest pixels ${theme}`);
  pressRest.push({ theme, files, sha256: hashes[0], result: 'Full native PNG byte equality across the press-only implementation fix. Not source parity.' });
}
const report = { checkedAt: new Date().toISOString(), runs, totalPngs: runs.reduce((sum, r) => sum+r.pngHashesVerified,0), labeledVideosVerified: labeled.length, pressRest, originalFrozenBeforeChecks: before.split('\n').filter(l => l.endsWith(': OK')).length, originalRound1RecordUnchanged: { recordings: original.runs.length, pngs: originalPngsVerified } };
await writeFile(path.join(root, 'verification.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify({ runs: runs.length, totalPngs: report.totalPngs, originalFrozenBeforeChecks: report.originalFrozenBeforeChecks, originalRound1: report.originalRound1RecordUnchanged }, null, 2));
