import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = import.meta.dirname;
const output = join(root, 'change-videos');
await mkdir(output);
const changes = {
  tooltip: 'Immediate keyboard reveal, touch toggle, pointer grace, overlapping arrow, and source scale/fade timing.',
  timeline: 'Replace invented media with the real source chart data, SVG/CSS tiles, theme colors, and captions.',
  alert: 'Use four source variants, upward entry/exit without scale, settled initial mount, and retained exiting icons.',
  'color-selector': 'Restore the vertical label, low selection arc, press spring, disabled choices, and radio keyboard behavior.',
  'arc-picker': 'Expand bracket spacing by 6px and compress height by 8% during drag and wheel activity.',
  tabs: 'Use the pinned source indicator spring. The blocks worker owns overflow and panel-layout corrections.',
  card: 'Restore full-card checkbox activation, source spacing and copy, transparent muted border, and the true Studio media card.',
  breadcrumb: 'Restore source width, spacing, forward navigation row, link metrics, and current-page focus restoration.',
  'image-viewer': 'Restore the exact photos, equal-width gallery columns, source copy, and press scale. Remove invented hover effects.',
};
const interactive = new Set(['tooltip', 'timeline', 'alert', 'color-selector', 'arc-picker', 'tabs']);
const beforeSlug = { 'image-viewer': 'morphing-lightbox' };
const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const page = await browser.newPage({ viewport: { width: 1440, height: 200 } });
const manifest = [];
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const probe = path => {
  const result = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_read_frames', '-show_entries', 'format=duration', '-of', 'json', path], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(result.stderr);
  return JSON.parse(result.stdout);
};
try {
  for (const [slug, change] of Object.entries(changes)) {
    for (const theme of ['light', 'dark']) {
      const before = join(root, interactive.has(slug) ? 'before-interactions' : 'before-verified', 'candidate', theme, beforeSlug[slug] ?? slug, 'recording.webm');
      const after = join(root, 'release-recordings-run2', `candidate-${theme}-${slug}`, 'capture.mp4');
      const parts = [];
      const frameProof = [];
      for (const [phase, input] of [['BEFORE', before], ['AFTER', after]]) {
        await page.setContent(`<div id="caption" style="box-sizing:border-box;width:1440px;height:120px;background:#111;color:white;padding:10px 20px;font-family:Arial"><div style="font-size:24px;font-weight:700">${escape(`${slug} / ${theme} / ${phase}`)}</div><div style="font-size:18px;line-height:23px">${escape(change)}</div><div style="font-size:13px;color:#bbb">${escape(phase === 'BEFORE' ? 'Pristine baseline 5ec78ac. Original 1440px viewport, no width wrapper. ' + (interactive.has(slug) ? 'Recorded actions.' : 'Static inventory recording.') : 'Repaired release 8ccb169. 1280px viewport, measured previewWidth=592. Native cadence only. Exact parity unproven.')}</div></div><style>html,body{margin:0}</style>`);
        const caption = join(output, `${slug}-${theme}-${phase.toLowerCase()}-caption.png`);
        await page.locator('#caption').screenshot({ path: caption });
        const part = join(output, `${slug}-${theme}-${phase.toLowerCase()}.mp4`);
        const result = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', input, '-i', caption,
          '-filter_complex', '[0:v]pad=1440:1120:(ow-iw)/2:120:color=black[base];[base][1:v]overlay=0:0:format=auto[out]',
          '-map', '[out]', '-an', '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '0', '-pix_fmt', 'yuv444p', '-video_track_timescale', '1000000', part], { encoding: 'utf8' });
        if (result.status !== 0) throw new Error(`${slug} ${phase}: ${result.stderr}`);
        const original = probe(input);
        const presentation = probe(part);
        if (original.streams[0].nb_read_frames !== presentation.streams[0].nb_read_frames) throw new Error(`${slug} ${phase}: presentation changed frame count`);
        frameProof.push({ phase, original, presentation });
        parts.push(part);
      }
      const concat = join(output, `${slug}-${theme}.ffconcat`);
      await writeFile(concat, 'ffconcat version 1.0\n' + parts.map(path => `file '${path}'`).join('\n') + '\n');
      const video = join(output, `${slug}-${theme}-before-after.mp4`);
      const result = spawnSync('ffmpeg', ['-nostdin', '-v', 'warning', '-f', 'concat', '-safe', '0', '-i', concat, '-c', 'copy', video], { encoding: 'utf8' });
      await writeFile(join(output, `${slug}-${theme}.log`), result.stderr);
      if (result.status !== 0) throw new Error(result.stderr);
      const decoded = probe(video);
      const expectedFrames = frameProof.reduce((sum, proof) => sum + Number(proof.original.streams[0].nb_read_frames), 0);
      if (Number(decoded.streams[0].nb_read_frames) !== expectedFrames) throw new Error(`${slug}: concatenation changed frame count`);
      manifest.push({ slug, theme, before, after, video, change, frameProof, decoded, comparison: 'Presentation only. Different original viewport widths are labeled. No rescaling or interpolation.' });
      await writeFile(join(output, 'index.json'), JSON.stringify(manifest, null, 2));
      console.log(video);
    }
  }
} finally { await browser.close(); }
