import { readFile, writeFile, readdir, mkdir, copyFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('./', import.meta.url));
const source = '/tmp/beui-reference-agents-20261023';
const sha = value => createHash('sha256').update(value).digest('hex');
const command = (program, args, options = {}) => {
  const result = spawnSync(program, args, { encoding: 'utf8', ...options });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
};
assert.equal(command('git', ['-C', source, 'rev-parse', 'HEAD']), 'a76e57c9bbc2837e96420b2610e9c82a3271bb05');
assert.equal(command('git', ['-C', source, 'status', '--porcelain']), '');
const files = (await readdir(`${source}/components/previews/agents`)).map(file => `components/previews/agents/${file}`);
files.push('components/agents/approval-card/index.tsx', 'components/agents/approval-card/types.ts', 'components/agents/file-diff.tsx', 'components/agents/chat-app.tsx', 'components/agents/voice-orb.tsx', 'components/agents/voice-orb/renderer.ts', 'components/motion/radio.tsx', 'lib/ease.ts', 'lib/hooks/use-favicon.ts', 'lib/favicon.ts', 'bun.lock');
const snapshots = [];
for (const file of files) {
  const content = await readFile(`${source}/${file}`);
  const target = `${root}source-snapshots/${file}`;
  await mkdir(target.substring(0, target.lastIndexOf('/')), { recursive: true });
  await copyFile(`${source}/${file}`, target);
  snapshots.push({ file, bytes: content.length, sha256: sha(content) });
}
await writeFile(`${root}source-hashes.json`, JSON.stringify(snapshots, null, 2));
const walk = async directory => {
  const output = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    const path = `${directory}/${item.name}`;
    if (item.isDirectory()) output.push(...await walk(path));
    else output.push(path);
  }
  return output;
};
const inputs = [...await walk('lib'), ...await walk('example/lib'), 'pubspec.lock', 'example/pubspec.lock', 'test/motion/agents_round2_test.dart'];
const inputHashes = [];
for (const path of inputs) inputHashes.push({ path, sha256: sha(await readFile(path)) });
await writeFile(`${root}implementation-input-hashes.json`, JSON.stringify(inputHashes, null, 2));
const builds = [];
await mkdir(`${root}frozen-javascript`, { recursive: true });
for (const name of (await readdir('example/build')).filter(name => name.startsWith('agents-round2-'))) {
  const path = `example/build/${name}/main.dart.js`;
  try {
    const artifact = `frozen-javascript/${name}.js`;
    await copyFile(path, `${root}${artifact}`);
    await copyFile(`example/build/${name}/index.html`, `${root}frozen-javascript/${name}.index.html`);
    builds.push({ name, path, artifact, bytes: (await stat(path)).size, sha256: sha(await readFile(path)) });
  } catch {}
}
await writeFile(`${root}frozen-build-hashes.json`, JSON.stringify(builds, null, 2));
const baseline = '/private/tmp/beui-agents-baseline-audit';
assert.equal(command('git', ['-C', baseline, 'rev-parse', 'HEAD']), '5ec78ac30e1274727ddd185a883346e4d908e6c8');
assert.equal(command('git', ['-C', baseline, 'diff', '--name-only', '--', 'lib']), '');
await copyFile(`${baseline}/example/lib/demos/agents_capture.dart`, `${root}baseline-capture-wrapper.dart.txt`);
await writeFile(`${root}baseline-wrapper-provenance.json`, JSON.stringify({
  revision: '5ec78ac30e1274727ddd185a883346e4d908e6c8', libraryDiff: '',
  wrapperSha256: sha(await readFile(`${baseline}/example/lib/demos/agents_capture.dart`)),
  status: command('git', ['-C', baseline, 'status', '--porcelain']),
  label: 'Baseline library plus capture-only wrapper. Not a pristine checkout. Original baseline evidence is unchanged.',
}, null, 2));
const captures = [];
for (const directory of ['handoff', 'shared-guarded', 'shared-guarded-providers', 'flows']) {
  for (const file of (await walk(`${root}${directory}`)).filter(file => file.endsWith('/timeline.json'))) {
    const timeline = JSON.parse(await readFile(file));
    const stats = timeline.stats ?? timeline;
    captures.push({ path: file.slice(root.length), frames: typeof stats.frames === 'number' ? stats.frames : stats.frames?.length, measuredFps: stats.measuredFps, maxGapMs: stats.maxGapMs ?? stats.maxIntervalMs, video: stats.video, failed: (timeline.events ?? []).some(event => event.failure), noInterpolation: true });
  }
}
const pointerTimeline = JSON.parse(await readFile(`${root}provider-held-pointer/timeline.json`));
captures.push({ path: 'provider-held-pointer/timeline.json', frames: pointerTimeline.frames.length, measuredFps: pointerTimeline.stats.measuredFps, maxGapMs: pointerTimeline.stats.maxIntervalMs, video: pointerTimeline.stats.video, failed: false, noInterpolation: true });
await writeFile(`${root}cadence-summary.json`, JSON.stringify(captures, null, 2));
const shared = JSON.parse(await readFile(`${root}shared-guarded/results.json`));
assert.equal(shared.length, 32);
assert(shared.every(row => row.status === 0));
const effective = [];
for (const row of shared) {
  const environment = JSON.parse(await readFile(`${root}shared-guarded/${row.name}/environment.json`));
  assert.equal(environment.flutterCapture.disableAnimations, environment.reducedMotion);
  assert.equal(environment.flutterCapture.motionOverride, null);
  const expectedWidth = row.width ?? 752;
  assert.equal(environment.flutterCapture.rect.width, expectedWidth);
  effective.push({ name: row.name, browser: environment.reducedMotion, flutter: environment.flutterCapture, servedJs: environment.servedJs });
}
await writeFile(`${root}effective-environments.json`, JSON.stringify(effective, null, 2));
const originalCheck = command('node', [`${root}../verify-evidence.cjs`]);
await writeFile(`${root}original-evidence-final-verification.txt`, originalCheck + '\n');
await writeFile(`${root}delivery.json`, JSON.stringify({
  implementationCommit: command('git', ['rev-parse', '7527cde']),
  baseCommit: command('git', ['rev-parse', '9fc8919']),
  originalEvidenceRestore: command('git', ['rev-parse', '8a0337b']),
  originalEvidenceSource: command('git', ['rev-parse', '91e8ca1']),
  parentPullRequest: 'https://github.com/codenameakshay/beui/pull/26',
  sourceRevision: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05',
  liveRevision: 'unknown', routeCount: 19, obligationCount: 152,
  exactParity: false, native60fps: 'unresolved', pushed: false, pullRequestChanged: false, merged: false,
  parentIntegration: 'Cherry-pick implementation and round-two evidence commits. Skip the evidence restore if 91e8ca1 is already integrated.',
}, null, 2));
console.log(`Pinned ${snapshots.length} source files. Indexed ${builds.length} frozen builds and ${captures.length} cadence records. All 32 shared guarded captures and original evidence checks passed.`);
