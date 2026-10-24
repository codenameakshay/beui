import { mkdir, readFile, copyFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';

const output = path.join(import.meta.dirname, 'logs');
await mkdir(output, { recursive: true });
const files = [
  'beui-parent-blocks-picker-tests.log', 'beui-parent-gallery-blocks-picker.log',
  'beui-card-parent-tooltip-before.log', 'beui-card-semantics-nodes-before.log',
  'beui-card-semantics-after.log', 'beui-card-semantics-after2.log', 'beui-card-semantics-after3.log',
  'beui-card-integration-final2.log', 'beui-svg-invalid-before.log', 'beui-svg-invalid-after1.log', 'beui-svg-invalid-after2.log', 'beui-svg-invalid-after3.log',
  'beui-block-integration-after.log', 'beui-gallery-integration-after.log', 'beui-feedback-policy-before.log', 'beui-feedback-policy-after.log',
  'beui-card-controls-after.log', 'beui-card-controls-after2.log', 'beui-round3-focused.log', 'beui-round3-focused-final.log',
  'beui-round3-focused-final2.log', 'beui-round3-focused-final3.log', 'beui-round3-focused-final4.log',
  'beui-card-input-layer-after.log', 'beui-round3-owned-final.log', 'beui-card-web-semantics-test.log',
  'beui-probe-dom-diagnostic.log', 'beui-controls-dark.log', 'beui-controls-light-reduced.log',
  'beui-controls-dark-recovered.log', 'beui-controls-light-reduced-recovered.log',
  'beui-controls-dark-final.log', 'beui-controls-light-reduced-final.log', 'beui-policy-before-recovered.log',
  'beui-policy-after-dark.log', 'beui-policy-final-dark.log', 'beui-policy-final-light-reduced.log',
  'beui-round3-all-owned-final.log', 'beui-round3-gallery-complete.log', 'beui-round3-root-analyze-last.log', 'beui-round3-example-analyze-last.log',
  'beui-round3-build.log', 'beui-round3-build-final.log', 'beui-round3-build-complete.log',
  'beui-block-probe-build-final.log', 'beui-block-probe-build-web-focus.log',
  'beui-round3-originals-verify.log', 'beui-round3-round2-verify.log',
  'beui-round3-policy-head-dark.log', 'beui-round3-policy-head-light-reduced.log', 'beui-round3-glyph-head.log',
  'beui-round3-policy-head-light-reduced-ready.log',
  'beui-card-longhold-before.log', 'beui-card-longhold-before-browser.log',
  'beui-card-feedback-tooltip12155.log', 'beui-card-feedback-tooltip12155-behavior.log',
  'beui-round3-build-tooltip12155.log', 'beui-round3-analyze-tooltip12155.log',
  'beui-card-longhold-after-dark.log', 'beui-card-longhold-after-light-reduced.log', 'beui-card-longhold-reference.log',
  'beui-round3-owned-tooltip12155.log', 'beui-gallery-tooltip12155.log',
  'beui-parent-gallery-donut-fixed.log', 'beui-round3-gallery-all-before-await.log', 'beui-round3-gallery-all-after-await.log',
  'beui-round3-gallery-parallel-after-await.log', 'beui-round3-example-analyze-await.log',
  'beui-parent-gallery-svg-wait-fixed.log',
];
const manifest = [];
for (const name of files) {
  const source = path.join('/tmp', name);
  const bytes = await readFile(source);
  const destination = path.join(output, name);
  try {
    const existing = await readFile(destination);
    if (!existing.equals(bytes)) throw new Error(`Raw log changed after collection: ${name}`);
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    await copyFile(source, destination);
  }
  manifest.push({ name, sha256: createHash('sha256').update(bytes).digest('hex'), bytes: bytes.length });
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
