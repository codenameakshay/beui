const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = __dirname;
const repo = path.resolve(root, '../../../..');
const audit = process.argv[2];
const referenceCheckout = process.argv[3];
const implementationCommit = '56f83f4fe5606a87999274508a9109c4419eeb81';
if (!audit || !referenceCheckout) {
  throw new Error('Pass the parent audit directory and pinned reference checkout.');
}
const run = (command, args, cwd = repo) => execFileSync(command, args, { cwd, encoding: 'utf8' }).trim();
if (run('git', ['diff', '--name-only', implementationCommit, '--', 'lib', 'example/lib'])) {
  throw new Error('The checkout code differs from the recorded implementation. Refusing to relabel its evidence.');
}
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const write = (name, data) => fs.writeFileSync(path.join(root, name), `${JSON.stringify(data, null, 2)}\n`);
const walk = directory => fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
  const file = path.join(directory, entry.name);
  return entry.isDirectory() ? walk(file) : [file];
});

const inventory = JSON.parse(fs.readFileSync(path.join(audit, 'inventory.json')));
const states = JSON.parse(fs.readFileSync(path.join(audit, 'states.json')));
const routes = inventory.rows.filter(row => row.family === 'agents').map(row => ({
  ...row,
  candidateDemoSha256: hash(path.join(repo, row.demo)),
  sourcePreviewHashes: row.sourcePreviewCandidates.map(file => ({ path: file, sha256: hash(path.join(referenceCheckout, file)) })),
  states: [
    'rest', 'hover-exit', 'keyboard', 'reduced-motion',
    ...states[row.slug],
    ...row.sourceExamples.map(example => `example/${example.installSlug}/${example.slug}`),
  ].map(state => ({ state, verdict: 'unverified', reason: row.sourceUrl ? 'Matched state-specific visual and temporal review is not complete.' : 'Local-only composition. No source route exists.' })),
}));
write('route-inventory.json', {
  baseline: inventory.before,
  source: inventory.reference,
  auditCommit: 'fe9213f',
  auditInventorySha256: hash(path.join(audit, 'inventory.json')),
  auditStatesSha256: hash(path.join(audit, 'states.json')),
  routeCount: routes.length,
  obligationCount: routes.reduce((count, route) => count + route.states.length, 0),
  routes,
});

const recordings = walk(root).filter(file => /\.(webm|mp4)$/.test(file)).sort().map(file => {
  const relative = path.relative(root, file);
  const raw = run('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,duration:format=duration', '-of', 'json', file]);
  const metadata = JSON.parse(raw);
  const stream = metadata.streams[0];
  const [numerator, denominator] = stream.avg_frame_rate.split('/').map(Number);
  const fps = numerator / denominator;
  const route = routes.find(route => relative.split('/').some(part => part === route.slug || part.startsWith(`${route.slug}-dark-`) || part.startsWith(`${route.slug}-light-`) || part === `${route.slug}-before-after.mp4`));
  const derived = file.endsWith('.mp4');
  return {
    path: relative,
    route: route?.id ?? null,
    sha256: hash(file),
    bytes: fs.statSync(file).size,
    ffprobe: metadata,
    recordingKind: derived ? 'annotated derivative' : 'original browser WebM',
    nativeFps: derived ? null : fps,
    encodedFps: fps,
    fastMotionVerdict: fps < 60 ? 'inconclusive: native cadence is below 60 FPS' : 'unreviewed: cadence alone does not prove temporal parity',
  };
});
write('recordings.json', { ffprobeVersion: run('ffprobe', ['-version']).split('\n')[0], command: 'ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,duration:format=duration -of json <video>', recordings });

const selected = recordings.filter(record => /^(before|reference|final|change-videos)\//.test(record.path) || record.path === 'flows/final/agent-theme/recording.webm');
const rows = selected.map(record => {
  const stream = record.ffprobe.streams[0];
  return `| [${record.path}](${record.path}) | ${stream.width} × ${stream.height} | ${stream.avg_frame_rate} | ${stream.nb_read_frames} | ${record.ffprobe.format.duration} |`;
});
fs.writeFileSync(path.join(root, 'recordings.md'), `# Recording metadata\n\nThe before, reference, final, and functional theme WebMs are original native recordings. The change-videos MP4s are labeled derivatives described in [CHANGE_MANIFEST.md](CHANGE_MANIFEST.md). No video uses frame interpolation. Their 25 FPS cadence is insufficient for the required fast-motion verdict. Full digests and raw FFprobe objects are in [recordings.json](recordings.json). Every route remains unverified for exact parity.\n\n| Recording | Pixels | Native FPS | Frames | Seconds |\n|---|---:|---:|---:|---:|\n${rows.join('\n')}\n`);

const buildFiles = ['flutter_bootstrap.js', 'main.dart.js', 'version.json'];
const builds = ['before', 'after', 'final'].map(phase => ({
  phase,
  mode: 'release',
  renderer: 'canvaskit',
  directory: `example/build/agents-${phase}`,
  files: buildFiles.map(file => ({ path: file, sha256: hash(path.join(repo, `example/build/agents-${phase}`, file)) })),
}));
write('provenance.json', {
  implementationCommit,
  baselineCommit: '5ec78ac30e1274727ddd185a883346e4d908e6c8',
  referenceCheckout,
  referenceCommit: run('git', ['rev-parse', 'HEAD'], referenceCheckout),
  referenceDirtyFiles: run('git', ['status', '--porcelain'], referenceCheckout),
  liveDeploymentCommit: 'unknown',
  buildCommand: 'flutter build web -t lib/visual_harness.dart --base-href /agents-final/ --output build/agents-final --no-wasm-dry-run',
  dirtyFilesAtIndexTime: run('git', ['status', '--porcelain']),
  flutter: JSON.parse(run('flutter', ['--version', '--machine'])),
  browser: run('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', ['--version']),
  os: run('sw_vers', []),
  builds,
  display: { defaultViewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1, browserZoom: 'default, not independently measured', textScale: 'default, not independently measured', locale: 'not explicitly fixed', timezone: 'not explicitly fixed', reducedMotion: 'Browser context reducedMotion=reduce only in the named orb reduced capture. Flutter effective value was not independently logged.' },
  limitations: ['Full viewport videos include source documentation chrome. Matched widget crops are not complete for all routes.', 'Event timing is not synchronized across source, before, and after.', 'Only the orb has a Design Compare motion diagnostic. Its 63.6 score and negative temporal correlation do not prove parity.', 'The reduced orb result is static/null, not passing proof.', 'Intermediate after recordings predate the final implementation; final/ is the final release build.', 'Shared previewWidth only applies to explorer, not this unchanged visual_harness entrypoint. No wrapper was applied to the pristine baseline.', 'source-geometry.json contains supplemental later measurements, not geometry measured at original capture time.', 'change-videos adds labels and concatenates original videos. It does not prove repaired interactive transitions.'],
});
console.log(`${routes.length} routes, ${routes.reduce((count, route) => count + route.states.length, 0)} obligations, ${recordings.length} recording files indexed. No passing verdicts written.`);
