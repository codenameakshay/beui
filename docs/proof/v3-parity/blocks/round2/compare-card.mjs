import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const output = path.join(root, process.argv[2] || 'compare-card');
await mkdir(output);
const result = [];
for (const theme of ['dark', 'light']) {
  const inputs = [
    ['reference', 'reference', 'reference'],
    ['before', theme === 'dark' ? 'before-observed' : 'before-light', 'candidate'],
    ['after', 'after-final-card', 'candidate'],
  ];
  const crops = {};
  for (const [stage, batch, target] of inputs) {
    const flow = process.env.FROM_FLOWS === '1' && stage !== 'before';
    const name = `${target}-card-folder-${theme}${flow ? '-no-preference' : ''}`;
    const directory = path.join(root, flow ? 'flows-normal' : batch);
    const file = path.join(directory, `${name}-rest.png`);
    const elements = JSON.parse(await readFile(path.join(directory, `${name}-${flow ? 'assertions' : 'elements'}.json`), 'utf8'));
    const bounds = flow ? elements.targets.folder.measuredBounds : elements.find(e => e.label === 'Open Saurabh Chauhan, card ending in 0806, expires 08/29');
    if (!bounds || bounds.width !== 384) throw new Error('Unmatched card geometry');
    const region = { x: Math.floor(bounds.x) - 16, y: Math.floor(bounds.y) - 80, width: 416, height: 340 };
    const crop = path.join(output, `${stage}-${theme}.png`);
    const run = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', file, '-vf', `crop=${region.width}:${region.height}:${region.x}:${region.y}`, '-frames:v', '1', crop], { encoding: 'utf8' });
    if (run.status !== 0) throw new Error(run.stderr);
    crops[stage] = crop;
    result.push({ stage, theme, file: path.relative(root, file), sha256: createHash('sha256').update(await readFile(file)).digest('hex'), measuredBounds: bounds, region, subpixelRemainder: { x: bounds.x - Math.floor(bounds.x), y: bounds.y - Math.floor(bounds.y) }, crop: path.relative(root, crop) });
  }
  for (const stage of ['before', 'after']) {
    const args = ['-nostdin', '-i', crops.reference, '-i', crops[stage], '-lavfi', 'ssim', '-f', 'null', '-'];
    const run = spawnSync('ffmpeg', args, { encoding: 'utf8' });
    if (run.status !== 0) throw new Error(run.stderr);
    await writeFile(path.join(output, `${stage}-${theme}-ssim.log`), run.stderr);
    const score = Number(run.stderr.match(/All:([\d.]+)/)?.[1]);
    if (!Number.isFinite(score)) throw new Error('No SSIM');
    const diff = spawnSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', crops.reference, '-i', crops[stage], '-lavfi', 'blend=all_mode=difference', '-frames:v', '1', path.join(output, `${stage}-${theme}-difference.png`)], { encoding: 'utf8' });
    if (diff.status !== 0) throw new Error(diff.stderr);
    result.push({ stage, theme, ssim: score, verdict: score === 1 ? 'Exact crop equality needs pixel confirmation' : 'FAIL: nonzero visual difference', method: 'Native 416x340 crops, integer floor origins, no resampling, masking, font replacement or interpolation. Both include their original surrounding stage background. Rest-only diagnostic, not motion certification.' });
  }
}
await writeFile(path.join(output, 'result.json'), JSON.stringify(result, null, 2));
console.log(JSON.stringify(result.filter(r => r.ssim), null, 2));
