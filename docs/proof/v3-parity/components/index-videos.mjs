import { mkdir, readFile, writeFile, stat } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';

const root = import.meta.dirname;
const inventory = JSON.parse(await readFile(join(root, 'inventory.json'), 'utf8'));
const runs = JSON.parse(await readFile(join(root, 'release-recordings-run2/index.json'), 'utf8'));
const changes = JSON.parse(await readFile(join(root, 'change-videos/index.json'), 'utf8'));
const records = [];
const rows = [];
const mismatches = {
  tooltip: 'Failed pixel and temporal comparison, gallery focus mismatch, incomplete composition and animated text.',
  'adaptive-stepper': 'Liquid blur/contrast silhouette and 600ms overshooting geometry are absent.',
  'color-picker': 'Trigger-to-area morph is absent.',
  combobox: 'Workspace label, 48px trigger, and true 28px icon marks differ. Planned search target was missing.',
  'date-range-picker': 'Trigger includes weekdays and omits the year, unlike the reference.',
  'color-selector': 'Selected ring does not share the swatch press scale. Existing golden comparison fails.',
  alert: 'Tone colors and height trajectory remain unmatched. Existing golden comparison fails.',
  breadcrumb: 'Item exit retention and ellipsis morph remain unmatched. Existing golden comparison fails.',
  card: 'Existing golden comparison fails. Reference pixel parity remains unverified.',
  'image-viewer': 'Existing golden comparison fails. Modal zoom, pan, swipe, and focus sequences remain unverified.',
};
for (const route of inventory.routes) {
  const slug = route.id.split('/')[1];
  const captures = runs.filter(run => run.slug === slug);
  const entry = { ...route, captures: [], changeVideos: changes.filter(change => change.slug === slug) };
  for (const capture of captures) {
    const video = join(capture.runDirectory, 'capture.mp4');
    if (capture.code !== 0) { entry.captures.push({ ...capture, video: null }); continue; }
    const bytes = await readFile(video);
    const info = { path: relative(root, video), bytes: (await stat(video)).size, sha256: createHash('sha256').update(bytes).digest('hex') };
    records.push(info);
    entry.captures.push({ ...capture, video: info });
  }
  const candidate = theme => entry.captures.find(capture => capture.origin === 'candidate' && capture.theme === theme);
  const reference = theme => entry.captures.find(capture => capture.origin === 'reference' && capture.theme === theme);
  const link = capture => capture?.video ? `[video](${capture.video.path})` : 'missing';
  const notes = [...new Set(captures.flatMap(capture => capture.missingTargets))];
  const verdict = mismatches[slug] ? 'Known mismatch or failed visual gate' : 'Inconclusive';
  rows.push(`| ${slug} | ${route.newBadge ? 'yes' : 'no'} | ${link(candidate('light'))} | ${link(candidate('dark'))} | ${link(reference('light'))}, ${link(reference('dark'))} | ${verdict} | ${[mismatches[slug], notes.length ? `Missing planned targets: ${notes.join(', ')}` : 'Default preview only'].filter(Boolean).join(' ')} |`);
  entry.verdict = verdict;
  entry.knownGaps = mismatches[slug] ?? null;
  entry.coverage = 'Default preview recording only. No complete state or example parity certificate.';
  await mkdir(join(root, 'video-verdicts'), { recursive: true });
  await writeFile(join(root, 'video-verdicts', `${slug}.json`), JSON.stringify(entry, null, 2));
}
await writeFile(join(root, 'release-video-sha256.json'), JSON.stringify({ implementationHead: '8ccb169aa6d6786c451456f756af2087d2672c89', records }, null, 2));
const lines = [
  '# Component video index', '',
  'All 28 required routes are listed. A video is not a parity verdict. These are default previews, not all 223 state and example obligations.', '',
  'The source checkout is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The live deployment SHA is unknown. The repaired release is `8ccb169`.', '',
  'Every video uses real captured frames. Cadence and maximum gaps are in the neighboring `timeline.json`. No frame interpolation is used.', '',
  '| Route | Audit new badge | Repaired light | Repaired dark | Reference light, dark | Verdict | Coverage limit |',
  '|---|---|---|---|---|---|---|', ...rows, '',
  '## Labeled before and after videos', '',
  'These are presentation copies. They preserve original image dimensions inside a padded frame. The captions label the unmatched original baseline width.', '',
  ...changes.map(change => `- [${change.slug}, ${change.theme}](${relative(root, change.video)}). ${change.change}`), '',
  '## Tooltip keyboard attempts', '',
  'These videos expose failed gallery focus parity. After clicking Top, source Tab focuses Left. Candidate Tab starts at the header logo. See `MOTION_REVIEW.md`.', '',
  ...['reference', 'candidate'].flatMap(origin => ['light', 'dark'].map(theme => `- [${origin}, ${theme}](tooltip-keyboard-recordings/${origin}-${theme}-tooltip/capture.mp4).`)), '',
  '## Evidence limits', '',
  '- Original before files remain unchanged. Their hashes are in `before-sha256.json`.',
  '- Card, breadcrumb, and image-viewer before clips are static inventory recordings. Their captions state that limit.',
  '- Native 60 FPS is unresolved. The observed cadence cannot settle short transition timing.',
  '- The requested layout viewport is 1280 by 1000. The recorded surface is 1280 by 913. Long demos are vertically cropped in the videos. The full measurement PNGs remain available.',
  '- Tooltip light reference and repaired original PNGs are committed. Other original PNGs remain locally at the exact run directories and are hashed by their timelines.',
  '- Additional examples, reduced-motion branches, complete drag flows, focus traps, and interruption sequences remain incomplete.',
  '- The five unsuppressed golden failures remain open. See `VERIFICATION.md`.', '',
];
await writeFile(join(root, 'VIDEO_INDEX.md'), lines.join('\n'));
console.log(JSON.stringify({ routes: inventory.routes.length, successfulVideos: records.length, labeledChangeVideos: changes.length }));
