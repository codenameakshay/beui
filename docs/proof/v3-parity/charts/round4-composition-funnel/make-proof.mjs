import assert from 'node:assert/strict';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const out = `${root}/${process.argv[2] ?? 'labeled-proof'}`;
const revision = process.argv[4] ?? '74744136';
const finalPhase = process.argv[3] ?? 'final-v3';
await mkdir(out);
const browser = await chromium.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
for (const slug of ['composition-chart', 'funnel-chart']) {
  const phases = ['before', 'source-v3', finalPhase];
  const labels = ['BEFORE a2942181', 'PINNED SOURCE a76e57c9', `AFTER ${revision}`];
  const notes = ['Geometry only. Funnel input targets failed.', 'Source consumer controls differ from Flutter.', 'Exact served build. Pixels remain nonzero.'];
  for (let i = 0; i < phases.length; i++) {
    const page = await browser.newPage({viewport: {width: 1000, height: 77}});
    await page.setContent(`<style>body{margin:0;background:#222;color:white;padding:9px 16px;font:17px/1.5 Helvetica,Arial,sans-serif}strong{display:block;font-size:24px}</style><strong>${labels[i]}</strong>${notes[i]}`);
    await page.screenshot({path: `${out}/${slug}-${phases[i]}-label.png`});
    await page.close();
  }
  const args = phases.flatMap(phase => ['-i', `${root}/captures-${phase}/${slug}-reduce/capture.mp4`]);
  args.push(...phases.flatMap(phase => ['-loop', '1', '-i', `${out}/${slug}-${phase}-label.png`]));
  args.push(...phases.flatMap(phase => ['-i', `${root}/captures-${phase}/${slug}-reduce/captions.srt`]));
  const filters = phases.map((_, i) => `[${i}:v]pad=iw:ih+77:0:77:color=0x222222[p${i}];[p${i}][${i + 3}:v]overlay=0:0:shortest=1[v${i}]`).join(';') + ';[v0][v1][v2]hstack=inputs=3[video]';
  const result = spawnSync('ffmpeg', ['-v', 'error', ...args, '-filter_complex', filters, '-map', '[video]', '-map', '6:0', '-map', '7:0', '-map', '8:0', '-shortest', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-c:s', 'mov_text', '-metadata:s:s:0', 'title=Before', '-metadata:s:s:1', 'title=Pinned source', '-metadata:s:s:2', 'title=Final candidate', '-disposition:s:0', '0', '-disposition:s:1', '0', '-disposition:s:2', 'default', `${out}/${slug}-montage.mp4`], {encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
  const still = spawnSync('ffmpeg', ['-v', 'error', '-i', `${out}/${slug}-montage.mp4`, '-frames:v', '1', `${out}/${slug}-rest-montage.png`], {encoding: 'utf8'});
  assert.equal(still.status, 0, still.stderr);
}
await browser.close();
const metrics = JSON.parse(await readFile(`${root}/${process.argv[5] ?? 'static-final-v3'}/measured-pixels.json`));
const sections = [];
for (const slug of ['composition-chart', 'funnel-chart']) {
  const png = await readFile(`${out}/${slug}-rest-montage.png`);
  sections.push(`<section><h2>${slug}</h2><p>Before, pinned source, and final implementation. The montage adds labels and captions. It does not resize the native columns. The derived video is not a motion-timing measurement.</p><img alt="Labeled native before, source, and after ${slug}" src="data:image/png;base64,${png.toString('base64')}"><p><a href="${slug}-montage.mp4">Open the captioned video montage</a></p></section>`);
}
const table = metrics.map(row => `<tr><td>${row.slug.replace('-chart', '')} ${row.state}</td><td>${row.theme} ${row.viewport.width}px</td><td>${row.diff.changedPixelsByMaxChannelThreshold['0'].toLocaleString('en-US')}</td><td>${row.diff.meanAbsoluteChannelError.toFixed(4)}</td></tr>`).join('');
sections.push(`<section><h2>Native funnel replacement and reversal</h2><p>Source and final candidate retain their original videos. The HTML player scales only the viewing presentation. Cadence remains insufficient for short-trajectory certification.</p><div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px"><figure style="margin:0"><figcaption>Pinned source a76e57c9</figcaption><video controls preload="metadata" style="width:100%" src="../captures-input-source-v3/funnel-chart-motion-no-preference/capture.mp4"></video></figure><figure style="margin:0"><figcaption>Candidate ${revision}</figcaption><video controls preload="metadata" style="width:100%" src="../captures-input-${finalPhase}/funnel-chart-motion-no-preference/capture.mp4"></video></figure></div><p><a href="../captures-input-source-v3/funnel-chart-touch-reduce/capture.mp4">Source trusted touch</a> and <a href="../captures-input-${finalPhase}/funnel-chart-touch-reduce/capture.mp4">candidate trusted touch</a> retain the second-tap dismissal failure.</p></section>`);
await writeFile(`${out}/index.html`, `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Composition and funnel round-four evidence</title><style>body{margin:0;padding:24px;background:#151515;color:#eee;font:15px/1.5 system-ui,sans-serif}main{max-width:1300px;margin:auto}h1{font-size:26px}h2{font-size:20px;margin-top:32px}p{max-width:90ch;color:#bbb}img{width:100%;height:auto;border:1px solid #555}a{color:#8bc4ff}table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}th,td{text-align:left;border-bottom:1px solid #444;padding:8px}.status{border:1px solid #b6873e;padding:12px;color:#f4cf92}small{color:#bbb}</style><main><h1>Composition and funnel parity evidence</h1><p class="status">Exact parity is not certified. Native pixels are nonzero. Shared Tooltip still fails native mouse-click dismissal and second-touch-tap dismissal. The parent owns both repairs. Both unchanged chart golden comparisons fail.</p><p>The source is pinned at a76e57c9. The live deployment SHA is unknown. Final implementation head is ${revision}. Original PNGs, recordings, timelines, served script hashes, and motion probes remain separate from this viewing page.</p>${sections.join('')}<h2>Unscaled native plot differences</h2><p>Each implementation is cropped at its measured plot origin. No scaling or state normalization is applied. A changed pixel means any RGB channel differs by at least one.</p><table><thead><tr><th>Plot</th><th>Surface</th><th>Changed pixels</th><th>Mean error / 255</th></tr></thead><tbody>${table}</tbody></table><p>Consumer controls and inherited layout differ in the source fixture. These counts cover the chart plot, not whole-demo parity. Native cadence remains below reliable 60fps, so short trajectories and interruption timing remain inconclusive.</p></main></html>`, {flag: 'wx'});
console.log('Created labeled, unscaled viewing montages and self-contained image proof page.');
