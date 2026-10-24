import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import path from 'node:path';

const root = import.meta.dirname;
const output = path.join(root, process.argv[2] || 'labeled-final');
await mkdir(output);
const pressOnly = process.env.PRESS_ONLY === '1';
const cases = pressOnly ? [
  ['card-held-press-dark', 'press-before/candidate-dark-no-preference/capture.mp4', 'press-after/candidate-dark-no-preference/capture.mp4', 'Held upper-card press scales only the back/card layer. Front pocket stays stationary.'],
  ['card-held-press-light', 'press-before/candidate-light-no-preference/capture.mp4', 'press-after/candidate-light-no-preference/capture.mp4', 'Light-theme held upper-card press, release open and Enter close.'],
] : [
  ['card-folder', 'before-observed/candidate-card-folder-dark/capture.mp4', 'flows-normal/candidate-card-folder-dark-no-preference/capture.mp4', 'CSS radial glow, pocket geometry, shared privacy tooltip, pointer to keyboard'],
  ['card-tooltip', 'before-observed/candidate-card-folder-dark/capture.mp4', 'after-final-card/candidate-card-folder-dark/capture.mp4', 'Shared tooltip hover and final chip artwork. Pre-probe wrapper in both inputs.'],
  ['feedback-widget', 'before-observed/candidate-feedback-widget-dark/capture.mp4', 'flows-final-feedback/candidate-feedback-widget-dark-no-preference/capture.mp4', 'Source sentiment default, independent retry semantics, retry submission'],
  ['morphing-search-chips', 'before-chips/candidate-morphing-search-chips-dark/capture.mp4', 'flows-normal/candidate-morphing-search-chips-dark-no-preference/capture.mp4', 'Source backdrop gradients and grid, typed chip and Escape'],
  ['number', 'before-observed/candidate-number-dark/capture.mp4', 'after-secondary/candidate-number-dark/capture.mp4', 'Digit Swap zero-glyph metrics and Unicode; secondary number examples'],
  ['prediction-market-card', 'before-observed/candidate-prediction-market-card-dark/capture.mp4', 'after-svg-final/candidate-prediction-market-card-dark/capture.mp4', 'Actual source SVG through native vector decoder, filling its source slot'],
  ['svg-sizing', 'after-secondary/candidate-prediction-market-card-dark/capture.mp4', 'after-svg-final/candidate-prediction-market-card-dark/capture.mp4', 'Real viewBox1x1 SVG must fill the 48px header slot rather than shrink to 9px.'],
];
const probe = file => JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_read_frames:format=duration', '-of', 'json', file], { encoding: 'utf8' }));
const manifest = [];
for (const [slug, beforeFile, afterFile, change] of cases) {
  const before = path.join(root, beforeFile);
  const after = path.join(root, afterFile);
  const beforeProbe = probe(before);
  const afterProbe = probe(after);
  const height = Math.ceil((Math.max(beforeProbe.streams[0].height, afterProbe.streams[0].height) + 64) / 2) * 2;
  const labels = [
    pressOnly ? `ROUND2 before. ${slug}. Whole folder shrinks on hold. Width592, d831524 wrapper, pointer recorder d53695f.` : slug === 'svg-sizing' ? 'ROUND2 before SVG sizing fix. Native decoder works, but artwork shrinks to 9px. Width592, d831524 wrapper.' : `ROUND1 before. ${slug}. Width592, old wrapper. Original 5ec78ac remains separate.`,
    pressOnly ? `ROUND2 after. ${slug}. Only back/card shrink. Same viewport, wrapper and protocol. No exact parity or 60fps claim.` : slug === 'svg-sizing' ? 'ROUND2 after SVG sizing fix. Artwork fills source slot. Same viewport and wrapper. No device or exact-parity claim.' : `ROUND2 after. ${slug}. Width592, ${slug === 'card-tooltip' ? 'old wrapper; final card code' : 'd831524 wrapper; viewport differs'}. No exact parity or 60fps claim.`,
  ];
  const paths = labels.map((label, index) => {
    const file = path.join(output, `${slug}-${index}.png`);
    const run = spawnSync('swift', [path.join(root, '../video-label.swift'), file, label], { encoding: 'utf8' });
    if (run.status !== 0) throw new Error(run.stderr);
    return file;
  });
  const title = input => `[${input}:v]settb=AVTB,setpts=PTS-STARTPTS,pad=1280:${height}:0:64:color=black[b${input}];[b${input}][${input+2}:v]overlay=eof_action=repeat[v${input}]`;
  const destination = path.join(output, `${slug}.mp4`);
  const run = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', before, '-i', after, '-i', paths[0], '-i', paths[1], '-filter_complex', `${title(0)};${title(1)};[v0][v1]concat=n=2:v=1:a=0[v]`, '-map', '[v]', '-fps_mode', 'passthrough', '-enc_time_base', '1:1000000', '-c:v', 'libx264', '-preset', 'fast', '-qp', '0', '-pix_fmt', 'yuv444p', destination], { encoding: 'utf8' });
  if (run.status !== 0) throw new Error(run.stderr);
  const derivedProbe = probe(destination);
  const inputFrames = Number(beforeProbe.streams[0].nb_read_frames) + Number(afterProbe.streams[0].nb_read_frames);
  const outputFrames = Number(derivedProbe.streams[0].nb_read_frames);
  if (inputFrames !== outputFrames) throw new Error(`Changed frame count ${slug}`);
  manifest.push({ slug, change, beforeFile, afterFile, video: `${path.basename(output)}/${slug}.mp4`, sha256: createHash('sha256').update(await readFile(destination)).digest('hex'), labels, beforeProbe, afterProbe, derivedProbe, inputFrames, outputFrames, method: 'Sequential viewing edit, not aligned comparison. No scaling, masking, interpolation or duplicate frames. Black title and padding only. Round1 and round2 viewports and wrappers differ unless the labels state otherwise. Immutable 5ec78ac original remains at its existing path.' });
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log(JSON.stringify(manifest.map(({ slug, inputFrames, outputFrames }) => ({ slug, inputFrames, outputFrames })), null, 2));
