import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdir, readFile, writeFile, mkdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const root = resolve('docs/proof/v3-parity/agents/round3');
const output = resolve(root, process.argv[2]);
await mkdir(output);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const directories = (await readdir(root, { withFileTypes: true })).filter(entry => entry.isDirectory()).map(entry => entry.name);
const captures = [];
let checkedImages = 0;
for (const name of directories) {
  let record;
  try { record = JSON.parse(await readFile(`${root}/${name}/record.json`)); }
  catch (error) { if (error.code === 'ENOENT') continue; throw error; }
  const clippedStates = [];
  for (const item of [...record.frames, ...record.snapshots]) {
    const bytes = await readFile(`${root}/${name}/${item.file}`);
    assert.equal(hash(bytes), item.sha256, `${name}/${item.file}`);
    if (item.stage && item.stage.y + item.stage.height > bytes.readUInt32BE(20)) clippedStates.push(item.state);
    checkedImages++;
  }
  if (record.cadence) {
    const probe = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-show_streams', '-of', 'json', `${root}/${name}/capture.mp4`], { encoding: 'utf8' });
    assert.equal(probe.status, 0, probe.stderr);
    const stream = JSON.parse(probe.stdout).streams[0];
    assert.equal(Number(stream.nb_read_frames), record.frames.length, name);
    assert.equal(record.cadence.decodedFrames, record.frames.length, name);
  }
  captures.push({ name, phase: record.phase, slug: record.slug, theme: record.theme, motion: record.motion, buildJs: record.expectedJs, fontAssets: record.fontAssets ?? [], states: record.snapshots.map(s => s.state), clippedStates, failure: record.failure ?? null, errors: record.errors, cadence: record.cadence ?? null, environment: record.environment, keyboardTraversal: record.keyboardTraversal ?? [] });
}
const comparisons = [];
for (const name of directories.filter(name => name.startsWith('verified-') && name.endsWith('-comparison'))) {
  const result = JSON.parse(await readFile(`${root}/${name}/results.json`));
  for (const state of result.results) comparisons.push({ comparison: name, inputs: result.inputs, ...state });
}
assert.equal(captures.filter(c => c.name.startsWith('verified-')).length, 16);
assert.equal(directories.filter(name => name.startsWith('verified-') && name.endsWith('-comparison')).length, 16);
assert(captures.filter(c => c.name.startsWith('verified-')).every(c => !c.failure && !c.clippedStates.length && c.cadence));
const original = JSON.parse(await readFile('docs/proof/v3-parity/agents/route-inventory.json'));
const routes = original.routes.map(route => ({
  id: route.id,
  slug: route.slug,
  sourceEquivalent: route.slug !== 'agent-theme',
  currentEvidence: captures.filter(c => c.slug === route.slug && c.name.startsWith('verified-')).map(c => `${c.name}/record.json`),
  inheritedEvidence: '../round2/README.md',
  obligations: route.states.map(state => ({
    state: state.state,
    verdict: route.slug === 'agent-theme' ? 'No source equivalent. Functional obligation remains separate.' : 'Unverified exact parity.',
    reason: ['file-diff', 'approval-card', 'voice-orb'].includes(route.slug)
      ? 'Matched states have nonzero pixel differences. Transient samples are unsynchronized. See current evidence and state results; other API, interruption, hover, and native-frame obligations are not implied by these captures.'
      : 'No fresh route-specific round-three equivalence proof. Inherited functional evidence does not close exact visual or temporal parity.',
  })),
}));
assert.equal(routes.length, 19);
assert.equal(routes.reduce((n, route) => n + route.obligations.length, 0), 152);
const table = ['# Exact per-state results', '', 'Every nonzero result fails exact parity. Rows labeled after-next-dispatch, submitting, or row-N are unsynchronized snapshots, not temporal equivalence. The full actual semantics and request/receipt times remain in each record.', '', '| Comparison | State | Changed pixels | Total pixels |', '|---|---|---:|---:|', ...comparisons.map(c => `| [${c.comparison}](../${c.comparison}/results.json) | ${c.state} | ${c.regions[0].changedPixels} | ${c.regions[0].totalPixels} |`), ''];
await writeFile(`${output}/STATE_RESULTS.md`, table.join('\n'));
await writeFile(`${output}/obligations.json`, JSON.stringify({ sourceRevision: original.source, liveRevision: 'unknown', base: 'a2942181', routeCount: 19, obligationCount: 152, exactParityVerified: 0, routes }, null, 2));
await writeFile(`${output}/captures.json`, JSON.stringify({ checkedImages, captures, comparisons }, null, 2));
console.log(JSON.stringify({ checkedImages, captures: captures.length, rejected: captures.filter(c => c.failure).length, completedVideos: captures.filter(c => c.cadence).length, finalScenarios: 16, comparedStates: comparisons.length, exactParityVerified: 0 }));
