import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const held = process.argv[2] === 'held';
const outputName = held ? 'labeled-hold750' : 'labeled-head';
const output = path.join(root, outputName);
await mkdir(output);
const cases = held ? [
  ['privacy-hold750-dark', ['hold750-before-dark/recording/capture.mp4', 'hold750-after-dark/recording/capture.mp4'], ['Before dependency fix: 750ms mouse hold cancels privacy release. Original retained.', 'After shared Tooltip 12155d8e dependency: 750ms release reveals; Enter hides. No exact timing or 60fps claim.']],
  ['privacy-hold750-light-reduced', ['hold750-after-light-reduced/recording/capture.mp4'], ['Light/reduced: effective Flutter preference observed; 750ms privacy release and Enter. Dependency-only Tooltip fix.']],
  ['privacy-hold750-source', ['hold750-reference-dark/recording/capture.mp4'], ['Source live deployment unknown. Same 750ms mouse hold and Enter protocol; pinned source checkout a76e57c9 separate.']],
] : [
  ['feedback-policy-dark', ['policy-before-recovered-dark/candidate-feedback-widget-dark-no-preference/capture.mp4', 'policy-head-dark/candidate-feedback-widget-dark-no-preference/capture.mp4'], ['Before: empty submit enabled, draft retained on close. Original 5ec78ac remains untouched.', 'After: empty/whitespace disabled; Cancel and Escape discard drafts. Same width592 wrapper.']],
  ['card-privacy-dark', ['policy-before-recovered-dark/candidate-card-folder-dark-no-preference/capture.mp4', 'policy-head-dark/candidate-card-folder-dark-no-preference/capture.mp4'], ['Before: instant eye swap, shared Tooltip composition. Width592, d831524 wrapper.', 'After: 40px control; opacity/scale/blur eye swap. Sparse capture is not exact timing proof.']],
  ['feedback-source-light-reduced', ['policy-final-light-reduced/reference-feedback-widget-light-reduce/capture.mp4', 'policy-head-light-reduced-ready/candidate-feedback-widget-light-reduce/capture.mp4'], ['Source live deployment unknown. Light, browser reduced motion. Pinned checkout a76e57c9 separate.', 'Candidate: effective Flutter reduced motion verified. Sequential viewing edit, not pixel equivalence.']],
  ['card-source-light-reduced', ['policy-final-light-reduced/reference-card-folder-light-reduce/capture.mp4', 'policy-head-light-reduced-ready/candidate-card-folder-light-reduce/capture.mp4'], ['Source: light reduced-motion privacy flow. Actual measured target coordinates retained.', 'Candidate: opacity-only eye fade, 120ms. No movement blur. Not exact image/motion certification.']],
  ['glyph-readiness', ['../round2/press-reduced/candidate-dark-reduce/capture.mp4', 'glyph-head-ready/recording/capture.mp4'], ['FAILED ORIGINAL: missing Lucide and monospace glyphs. Original files unchanged.', 'Replacement: font bodies hashed before first screenshot. Decoded glyph inspection required. Historical trigger unproven.']],
  ['controls-dark', ['controls-dark-final/recording/capture.mp4'], ['New contract fixture: held optional action, Enter callback, privacy reversal, disabled controls and missing SVG. Not reference wrapper.']],
  ['controls-light-reduced', ['controls-light-reduced-final/recording/capture.mp4'], ['New light/reduced contract fixture. Effective Flutter preference observed. No exact parity or native 60fps claim.']],
];
const probe = file => JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_read_frames:format=duration', '-of', 'json', file], { encoding: 'utf8' }));
const manifest = [];
for (const [name, inputs, labels] of cases) {
  const files = inputs.map(file => path.join(root, file));
  const probes = files.map(probe);
  const height = Math.ceil((Math.max(...probes.map(p => p.streams[0].height)) + 64) / 2) * 2;
  const titleFiles = labels.map((label, index) => {
    const file = path.join(output, `${name}-${index}.png`);
    execFileSync('swift', [path.join(root, '../video-label.swift'), file, label]);
    return file;
  });
  const filter = files.map((_, index) => `[${index}:v]settb=AVTB,setpts=PTS-STARTPTS,pad=1280:${height}:0:64:color=black[b${index}];[b${index}][${index + files.length}:v]overlay=eof_action=repeat[v${index}]`).join(';');
  const concat = files.length === 1 ? '[v0]null[v]' : files.map((_, index) => `[v${index}]`).join('') + `concat=n=${files.length}:v=1:a=0[v]`;
  const file = path.join(output, `${name}.mp4`);
  execFileSync('ffmpeg', ['-nostdin', '-v', 'error', ...files.flatMap(f => ['-i', f]), ...titleFiles.flatMap(f => ['-i', f]), '-filter_complex', `${filter};${concat}`, '-map', '[v]', '-fps_mode', 'passthrough', '-enc_time_base', '1:1000000', '-c:v', 'libx264', '-preset', 'fast', '-qp', '0', '-pix_fmt', 'yuv444p', file]);
  const result = probe(file);
  const inputFrames = probes.reduce((total, p) => total + Number(p.streams[0].nb_read_frames), 0);
  assert.equal(Number(result.streams[0].nb_read_frames), inputFrames);
  manifest.push({ name, inputs, labels, probes, result, inputFrames, outputFrames: inputFrames, file: `${outputName}/${name}.mp4`, sha256: createHash('sha256').update(await readFile(file)).digest('hex'), method: 'Original pixels not resized. Black label band and padding only. Sequential edit, not aligned comparison. No interpolation or generated motion samples.' });
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
