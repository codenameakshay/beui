import {mkdir, readFile, writeFile, readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync, spawnSync} from 'node:child_process';
import {join} from 'node:path';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const source = '/tmp/beui-round4-composition-funnel-source-v3-20261023';
const candidate = process.argv[2];
const revision = process.argv[3];
if (!candidate || !revision) throw Error('Pass the candidate build directory and exact implementation revision.');
const sourceArchive = process.argv[4] ?? 'source-build-v3';
const suffix = process.argv[5] ? `-${process.argv[5]}` : '';
await mkdir(`${root}/${sourceArchive}`);
for (const file of await readdir(source)) {
  await writeFile(`${root}/${sourceArchive}/${file}`, await readFile(join(source, file)), {flag: 'wx'});
}
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const paths = [
  'lib/src/charts/composition_chart.dart',
  'lib/src/charts/funnel_chart.dart',
  'lib/src/charts/_shared.dart',
  'lib/src/motion/tooltip.dart',
  'example/lib/demos/composition_chart_demo.dart',
  'example/lib/demos/funnel_chart_demo.dart',
  'example/lib/visual_harness.dart',
  'example/lib/explorer/capture_probe.dart',
  'tool/parity_capture.mjs',
  'test/charts/touch_capture_round3.mjs',
  'pubspec.lock',
  'example/pubspec.lock',
];
const inputs = await Promise.all(paths.map(async path => {
  const blob = spawnSync('git', ['rev-parse', '--verify', `${revision}:${path}`], {encoding: 'utf8'});
  return {path, sha256: hash(await readFile(path)), gitBlob: blob.status === 0 ? blob.stdout.trim() : null};
}));
await mkdir(`${root}/input-locks${suffix}`);
for (const [path, name] of [['pubspec.lock', 'library-pubspec.lock'], ['example/pubspec.lock', 'example-pubspec.lock']]) await writeFile(`${root}/input-locks${suffix}/${name}`, await readFile(path), {flag: 'wx'});
await writeFile(`${root}/build-provenance${suffix}.json`, JSON.stringify({revision, candidate, candidateJavascriptSha256: hash(await readFile(join(candidate, 'main.dart.js'))), pinnedSource: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', sourceDeploymentSha: null, sourceJavascriptSha256: hash(await readFile(join(source, 'source.js'))), flutter: JSON.parse(execFileSync('flutter', ['--version', '--machine'], {encoding: 'utf8'})), inputs}, null, 2), {flag: 'wx'});

const motionRoot = '/tmp/beui-charts-fixture-runtime-20261023/node_modules';
const easePath = `${motionRoot}/motion-utils/dist/es/easing/ease.mjs`;
const transitionPath = `${motionRoot}/motion-dom/dist/es/animation/interfaces/motion-value.mjs`;
const {easeOut} = await import(easePath);
const transition = await readFile(transitionPath, 'utf8');
const css = await readFile(`${source}/source.css`, 'utf8');
if (!transition.includes('ease: "easeOut"')) throw Error('Runtime default easing changed.');
const easingInputs = [easePath, transitionPath].map(path => ({path}));
for (const input of easingInputs) {
  const bytes = await readFile(input.path);
  input.sha256 = hash(bytes);
  input.contents = bytes.toString();
}
await writeFile(`${root}/source-easing-results${suffix}.json`, JSON.stringify({area: {durationMs: 180, curve: [0, 0, .58, 1], midpoint: easeOut(.5)}, funnelHover: {durationMs: 150, curve: [.4, 0, .2, 1], sourceRule: css.match(/\.transition-colors\{[^}]+\}/)?.[0]}, legend: {durationMs: 150, cssDefault: css.match(/--default-transition-timing-function:[^;}]+/)?.[0]}, inputs: easingInputs}, null, 2), {flag: 'wx'});
console.log('Archived served source bundle, runtime lock, fonts, and exact-head build inputs.');
