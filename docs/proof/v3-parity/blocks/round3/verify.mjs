import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const json = async file => JSON.parse(await readFile(file, 'utf8'));
async function filesUnder(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await filesUnder(file));
    else files.push(file);
  }
  return files;
}
const probe = file => JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_read_frames:format=duration', '-of', 'json', file], { encoding: 'utf8' }));
async function verifyFrames(directory) {
  const timeline = await json(path.join(directory, 'timeline.json'));
  for (const frame of timeline.frames) {
    assert.equal(sha(await readFile(path.join(directory, frame.file))), frame.sha256, `${directory}/${frame.file}`);
    assert(frame.receivedMs >= frame.requestedMs);
  }
  const decoded = probe(path.join(directory, 'capture.mp4'));
  assert.equal(Number(decoded.streams[0].nb_read_frames), timeline.frames.length, directory);
  return { timeline, decoded };
}

const allFiles = await filesUnder(root);
const runs = [];
for (const file of allFiles.filter(file => path.basename(file) === 'timeline.json').sort()) {
  const directory = path.dirname(file);
  const { timeline, decoded } = await verifyFrames(directory);
  const config = await json(path.join(directory, 'config.json'));
  const environment = await json(path.join(directory, 'environment.json'));
  assert.equal(environment.reducedMotion, config.reducedMotion === 'reduce');
  if (config.requireFlutterProbe) {
    assert.equal(environment.flutterCapture.disableAnimations, config.reducedMotion === 'reduce');
  }
  if (config.servedJs) {
    const scripts = await json(path.join(directory, 'scripts.json'));
    assert(scripts.some(script => script.url === config.servedJs.url && script.status === 200 && script.sha256 === config.servedJs.sha256), directory);
  }
  runs.push({ directory: path.relative(root, directory), originalPngsVerified: timeline.frames.length, decoded,
    measuredFps: timeline.stats.measuredFps, maxIntervalMs: timeline.stats.maxIntervalMs,
    events: timeline.events, dispatchErrors: timeline.events.filter(event => event.error),
    effectiveFlutter: environment.flutterCapture ?? null, servedJs: config.servedJs ?? null,
    verdict: 'Fast motion remains inconclusive. Dispatch and frame preservation do not establish the resulting state or exact parity.' });
}

const labeled = [];
for (const name of ['labeled', 'labeled-head', 'labeled-hold750']) {
  for (const item of await json(path.join(root, name, 'manifest.json'))) {
    const file = path.join(root, item.file);
    assert.equal(sha(await readFile(file)), item.sha256);
    const frames = Number(probe(file).streams[0].nb_read_frames);
    assert.equal(frames, item.inputFrames);
    let inputs = 0;
    for (const input of item.inputs) inputs += Number(probe(path.join(root, input)).streams[0].nb_read_frames);
    assert.equal(frames, inputs);
    labeled.push({ file: item.file, sha256: item.sha256, frames });
  }
}

const original = await json(path.join(root, '../verification.json'));
let round1Pngs = 0;
for (const run of original.runs) {
  const { timeline } = await verifyFrames(path.join(root, '..', run.path));
  round1Pngs += timeline.frames.length;
}
assert.equal(round1Pngs, 2710);
let round2Pngs = 0;
for (const file of (await filesUnder(path.join(root, '../round2'))).filter(file => path.basename(file) === 'timeline.json')) {
  const { timeline } = await verifyFrames(path.dirname(file));
  round2Pngs += timeline.frames.length;
}
assert.equal(round2Pngs, 6878);
const before = execFileSync('shasum', ['-a', '256', '-c', path.join(root, '../before-sha256.txt')], { cwd: path.resolve(root, '../../../../..'), encoding: 'utf8' });
const beforeEntries = before.split('\n').filter(line => line.endsWith(': OK')).length;
assert.equal(beforeEntries, 185);

const fontProof = await json(path.join(root, 'glyph-head-ready/font-responses.json'));
for (const suffix of ['/lucide.ttf', '/GeistMono-Regular.ttf', '/Geist-Regular.ttf']) {
  const font = fontProof.fonts.find(font => font.url.endsWith(suffix));
  assert(font && font.status === 200 && font.bytes > 0 && /^[a-f0-9]{64}$/.test(font.sha256));
  assert(Date.parse(font.completedAt) < Date.parse(fontProof.beforeFirstCaptureAt));
}
const assertions = [];
for (const file of allFiles.filter(file => file.endsWith('assertions.json'))) {
  const result = await json(file);
  assertions.push({ file: path.relative(root, file), pass: result.pass === true, error: result.error ?? null });
}
for (const batch of ['policy-head-dark', 'policy-head-light-reduced-ready']) {
  for (const slug of ['feedback-widget', 'card-folder']) {
    const file = assertions.find(item => item.file.startsWith(`${batch}/candidate-${slug}-`));
    assert(file?.pass, `${batch}/${slug}`);
  }
}
for (const batch of ['controls-dark-final', 'controls-light-reduced-final']) {
  assert((await json(path.join(root, batch, 'assertions.json'))).pass);
}
for (const batch of ['hold750-before-dark', 'hold750-after-dark', 'hold750-after-light-reduced', 'hold750-reference-dark']) {
  const result = await json(path.join(root, batch, 'assertions.json'));
  assert(result.pass, batch);
  assert(result.releasedAt - result.downAt >= 750, batch);
  assert.equal(result.revealedAfterRelease, batch !== 'hold750-before-dark');
  if (batch !== 'hold750-before-dark') assert.equal(result.hiddenAfterEnter, true);
}

const pngHashes = [];
for (const file of allFiles.filter(file => file.endsWith('.png') && !file.includes('/original-frames/'))) {
  pngHashes.push({ file: path.relative(root, file), sha256: sha(await readFile(file)) });
}
const report = { runs, newOriginalPngsVerified: runs.reduce((sum, run) => sum + run.originalPngsVerified, 0), labeled,
  originalEvidenceUnchanged: { round1Pngs, round2Pngs, beforeEntries }, assertions, diagnosticPngs: pngHashes,
  fontReadiness: 'Required font HTTP bodies completed before first screenshot. Decoded glyphs require visual inspection. Historical failure trigger remains unproven.',
  verdict: 'No exact image, motion, native application, or 60 FPS parity established.' };
await writeFile(path.join(root, 'verification.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify({ runs: runs.length, newOriginalPngsVerified: report.newOriginalPngsVerified, labeledVideos: labeled.length, originalEvidenceUnchanged: report.originalEvidenceUnchanged }, null, 2));
