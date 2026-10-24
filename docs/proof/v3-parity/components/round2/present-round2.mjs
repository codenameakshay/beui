import assert from 'node:assert/strict';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { spawnSync } from 'node:child_process';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = import.meta.dirname;
const originalRoot = process.argv[2];
assert(originalRoot, 'Provide the checkout containing the preserved before recordings');
const output = join(root, 'presentations');
await mkdir(output);
const changed = {
  'adaptive-stepper': 'Liquid silhouette and 600ms overshoot. Min/max and interrupted direction changes.',
  alert: 'Source tones and height; caller-only 28px tabs; dismiss, return focus, and reopen.',
  breadcrumb: 'Retained exit and hit-test extent; 32px ellipsis; stable hover and inert held route after Escape.',
  'color-picker': 'Trigger-area morph; spectrum drag; format changes; accessible increments and reduced-motion loupe.',
  'color-selector': 'Selected ring shares swatch press scale. Pointer selection and keyboard movement.',
  combobox: 'Source 48px trigger and 28px marks. Real Product query filters and selects Product team.',
  'date-range-picker': 'Source dates, year, no weekday. Keyboard range selection and ambient Geist metrics.',
  'image-viewer': 'Source gaps; clipped zoom and pan; swipe paging; inert held controls after Escape; focus return.',
  tooltip: 'External anchors, exclusivity, warm timing, toolbar and text transition; long mouse hold preserves child click.',
};
const defaults = ['timeline', 'collapsible', 'aspect-ratio', 'arc-picker', 'sortable-stack', 'card', 'expandable-control', 'multi-select', 'file-tree'];
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const run = (command, args) => {
  const result = spawnSync(command, args, { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout;
};
const probe = path => JSON.parse(run('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_read_frames', '-show_entries', 'format=duration', '-of', 'json', path]));
const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const page = await browser.newPage({ viewport: { width: 1440, height: 180 } });
const manifest = [];
try {
  for (const slug of [...Object.keys(changed), ...defaults]) {
    for (const theme of ['light', 'dark']) {
      let batch = defaults.includes(slug) ? 'new-widgets-final' : 'functional-final';
      if (['combobox', 'breadcrumb'].includes(slug)) batch = 'final-repairs';
      if (slug === 'tooltip') batch = 'final-controls';
      if (slug === 'color-picker' && theme === 'light') batch = 'functional-final-corrected';
      const recording = join(root, batch, `candidate-${theme}-no-preference-${slug}`);
      const config = JSON.parse(await readFile(join(recording, 'record-config.json')));
      const beforeSlug = slug === 'image-viewer' ? 'morphing-lightbox' : slug;
      const before = join(originalRoot, 'docs/proof/v3-parity/components/before/candidate', theme, beforeSlug, 'recording.webm');
      const after = join(recording, 'recording/capture.mp4');
      const change = changed[slug] ?? 'New-widget default preview only. No interaction or complete-state certification.';
      const frameProof = [];
      const parts = [];
      for (const [phase, input] of [['BEFORE', before], ['AFTER', after]]) {
        const metadata = probe(input);
        const dimensions = `${metadata.streams[0].width}x${metadata.streams[0].height}`;
        const provenance = phase === 'BEFORE'
          ? `Preserved original inventory recording, 5ec78ac. Original ${dimensions}; unmatched viewport and wrapper.`
          : `Build ${config.provenance.revision.slice(0, 8)}. Original ${dimensions}; previewWidth=592, Blue palette. ${defaults.includes(slug) ? 'Default only.' : 'Observed actions are linked separately.'}`;
        await page.setContent(`<style>html,body{margin:0}</style><div id="caption" style="box-sizing:border-box;width:1440px;height:140px;background:#111;color:white;padding:12px 20px;font-family:Arial"><div style="font-size:24px;font-weight:700">${escape(`${slug} / ${theme} / ${phase}`)}</div><div style="font-size:18px;line-height:24px">${escape(change)}</div><div style="font-size:14px;line-height:20px;color:#ccc">${escape(provenance)}<br>Padding only. No scaling, masking, interpolation, or duplicated frames. Fast-motion parity inconclusive.</div></div>`);
        const caption = join(output, `${slug}-${theme}-${phase.toLowerCase()}-caption.png`);
        await page.locator('#caption').screenshot({ path: caption });
        const part = join(output, `${slug}-${theme}-${phase.toLowerCase()}.mp4`);
        run('ffmpeg', ['-nostdin', '-v', 'error', '-i', input, '-i', caption, '-filter_complex', '[0:v]pad=1440:1140:(ow-iw)/2:140:color=black[base];[base][1:v]overlay=0:0:format=auto[out]', '-map', '[out]', '-an', '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '0', '-pix_fmt', 'yuv444p', '-video_track_timescale', '1000000', part]);
        const padded = probe(part);
        assert.equal(padded.streams[0].nb_read_frames, metadata.streams[0].nb_read_frames, `${slug} ${phase} frame count`);
        frameProof.push({ phase, input: relative(root, input), original: metadata, padded });
        parts.push(part);
      }
      const concat = join(output, `${slug}-${theme}.ffconcat`);
      await writeFile(concat, 'ffconcat version 1.0\n' + parts.map(path => `file '${path}'`).join('\n') + '\n');
      const video = join(output, `${slug}-${theme}-before-after.mp4`);
      run('ffmpeg', ['-nostdin', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', concat, '-c', 'copy', video]);
      const decoded = probe(video);
      assert.equal(Number(decoded.streams[0].nb_read_frames), frameProof.reduce((sum, proof) => sum + Number(proof.original.streams[0].nb_read_frames), 0), `${slug} combined frame count`);
      manifest.push({ slug, theme, video: relative(root, video), after: relative(root, after), afterRevision: config.provenance.revision, change, coverage: defaults.includes(slug) ? 'default only' : 'observed functional actions; complete-state parity not claimed', frameProof, decoded });
      await writeFile(join(output, 'index.json'), JSON.stringify(manifest, null, 2));
      console.log(JSON.stringify({ slug, theme, frames: decoded.streams[0].nb_read_frames, video: relative(root, video) }));
    }
  }
} finally {
  await browser.close();
}
