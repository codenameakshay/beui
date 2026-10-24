import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import path from 'node:path';

const root = import.meta.dirname;
const output = path.join(root, process.argv[2] || 'change-videos');
await mkdir(output, { recursive: true });
const changes = [
  ['card-folder', 'Card contours, layer transforms, privacy digits, keyboard activation'],
  ['morphing-tabs', 'Equal slots, source gaps, content height, clipped narrow icons'],
  ['prediction-market-card', 'Source images, probability swap, payout tooltip, one CTA focus stop'],
  ['number', 'Outgoing digit direction, cancellable stagger, same-value style refresh'],
  ['text-animation', 'Scramble elapsed time and immediate nonpositive-duration completion'],
];
const probe = file => JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_read_frames:format=duration', '-of', 'json', file], { encoding: 'utf8' }));
const manifest = [];
for (const [slug, change] of changes.filter(([slug]) => !process.env.SLUGS || process.env.SLUGS.split(',').includes(slug))) {
  const beforePhase = ['number', 'text-animation'].includes(slug) ? 'before-expanded-actions' : 'before';
  const before = path.join(root, beforePhase, 'interactions/candidate', slug, 'interaction.webm');
  const after = path.join(root, process.env.AFTER_BATCH || 'recovered-dark', `candidate-${slug}`, 'capture.mp4');
  const destination = path.join(output, `${slug}.mp4`);
  const labels = [
    `BEFORE 5ec78ac - pristine original, default stage. ${slug}`,
    `AFTER ${process.env.CODE_HEAD || '34e2fc7'} - previewWidth592. ${process.env.CHANGE_TEXT || change}`,
  ];
  const labelPaths = labels.map((label, index) => {
    const file = path.join(output, `${slug}-${index}.png`);
    const run = spawnSync('swift', [path.join(root, 'video-label.swift'), file, label], { encoding: 'utf8' });
    if (run.status !== 0) throw new Error(run.stderr);
    return file;
  });
  const title = input => `[${input}:v]settb=AVTB,setpts=PTS-STARTPTS,pad=1280:964:0:64:color=black[b${input}];[b${input}][${input + 2}:v]overlay=eof_action=repeat[v${input}]`;
  const filter = [
    title(0),
    title(1),
    '[v0][v1]concat=n=2:v=1:a=0[v]',
  ].join(';');
  const run = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', before, '-i', after, '-i', labelPaths[0], '-i', labelPaths[1], '-filter_complex', filter, '-map', '[v]', '-fps_mode', 'passthrough', '-enc_time_base', '1:1000000', '-c:v', 'libx264', '-preset', 'fast', '-qp', '0', '-pix_fmt', 'yuv444p', destination], { encoding: 'utf8' });
  if (run.status !== 0) throw new Error(run.stderr);
  const beforeProbe = probe(before);
  const afterProbe = probe(after);
  const derivedProbe = probe(destination);
  const inputFrames = Number(beforeProbe.streams[0].nb_read_frames) + Number(afterProbe.streams[0].nb_read_frames);
  const outputFrames = Number(derivedProbe.streams[0].nb_read_frames);
  if (outputFrames !== inputFrames) throw new Error(`Frame count changed for ${slug}: ${inputFrames} to ${outputFrames}`);
  manifest.push({ slug, change, before: path.relative(root, before), after: path.relative(root, after),
    viewingVideo: path.relative(root, destination), sha256: createHash('sha256').update(await readFile(destination)).digest('hex'),
    beforeProbe, afterProbe, derivedProbe, inputFrames, outputFrames,
    method: 'Sequential before then after. Original pixels are not scaled. Black padding holds the title and fills the shorter capture. VFR passthrough, no interpolation or frame duplication. These differently staged and timed runs are not an aligned parity comparison.' });
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log(JSON.stringify(manifest.map(({ slug, viewingVideo, inputFrames, outputFrames }) => ({ slug, viewingVideo, inputFrames, outputFrames })), null, 2));
