const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const inventory = require('./route-inventory.json');
const recordings = require('./recordings.json').recordings;
const changes = require('./change-manifest.json');
const provenance = require('./provenance.json');

assert.equal(inventory.routeCount, 19);
assert.equal(inventory.obligationCount, 152);
assert.equal(provenance.implementationCommit, '56f83f4fe5606a87999274508a9109c4419eeb81');
assert.equal(provenance.baselineCommit, '5ec78ac30e1274727ddd185a883346e4d908e6c8');
assert.equal(provenance.referenceCommit, 'a76e57c9bbc2837e96420b2610e9c82a3271bb05');
assert.equal(provenance.referenceDirtyFiles, '');
const byPath = new Map(recordings.map(recording => [recording.path, recording]));
for (const recording of recordings) {
  const bytes = fs.readFileSync(path.join(__dirname, recording.path));
  assert.equal(bytes.length, recording.bytes, recording.path);
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), recording.sha256, recording.path);
}
for (const phase of ['before', 'reference', 'final']) {
  for (const route of inventory.routes.filter(route => route.sourceUrl)) {
    const recording = byPath.get(`${phase}/${route.slug}-dark-1440/recording.webm`);
    assert(recording, `${phase}/${route.slug}`);
    assert.equal(recording.route, route.id);
    assert.equal(recording.nativeFps, 25);
    assert.equal(recording.ffprobe.streams[0].width, 1440);
    assert.equal(recording.ffprobe.streams[0].height, 1000);
  }
  console.log(`${phase}: all 18 source-backed route originals indexed with native 25 FPS and 1440 by 1000 pixels.`);
}
assert.equal(changes.length, 18);
const frames = recording => Number(recording.ffprobe.streams[0].nb_read_frames);
for (const change of changes) {
  const output = byPath.get(change.video);
  assert.equal(output.route, change.route);
  assert.equal(frames(output), frames(byPath.get(change.before)) + frames(byPath.get(change.after)), change.route);
  assert.equal(output.ffprobe.streams[0].height, 1112);
  assert.equal(output.nativeFps, null);
}
const events = require('./flows/final/agent-theme/events.json');
assert(events.every(event => !event.error));
for (const name of ['expanded proposal', 'editor replaced with Shared layout proof', 'collapsed proposal', 'Approved', 'Rejected', 'Changes requested']) {
  assert(events.some(event => event.event === name), name);
}
assert(byPath.has('flows/final/agent-theme/recording.webm'));
console.log(`All ${recordings.length} recording file hashes and byte counts match.`);
console.log('All 18 labeled derivatives retain the exact summed input frame counts. No interpolated frames.');
console.log('Local-only theme flow contains all six asserted outcomes with no capture error.');
console.log('No exact-parity verdict is implied. The 152 state/example obligations remain unverified.');
