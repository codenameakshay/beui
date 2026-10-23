import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('./', import.meta.url));
const json = async path => JSON.parse(await readFile(`${root}${path}`));
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
for (const file of await json('source-hashes.json')) {
  assert.equal(sha(await readFile(`${root}source-snapshots/${file.file}`)), file.sha256, file.file);
}
for (const input of await json('implementation-input-hashes.json')) {
  assert.equal(sha(await readFile(input.path)), input.sha256, input.path);
}
for (const build of await json('frozen-build-hashes.json')) {
  assert.equal(sha(await readFile(`${root}${build.artifact}`)), build.sha256, build.artifact);
}
for (const item of await json('shared-guarded/results.json')) {
  assert.equal(item.status, 0, item.name);
  const config = await json(`shared-guarded/${item.name}/config.json`);
  const environment = await json(`shared-guarded/${item.name}/environment.json`);
  const scripts = await json(`shared-guarded/${item.name}/scripts.json`);
  assert(scripts.some(script => script.url === config.servedJs.url && script.sha256 === config.servedJs.sha256));
  assert.equal(environment.flutterCapture.motionOverride, null);
  assert.equal(environment.flutterCapture.disableAnimations, config.reducedMotion === 'reduce');
  assert.equal(environment.flutterCapture.rect.width, item.width ?? 752);
  const timeline = await json(`shared-guarded/${item.name}/timeline.json`);
  const probe = await json(`shared-guarded/${item.name}/ffprobe.json`);
  assert.equal(Number(probe.streams[0].nb_read_frames), timeline.frames.length);
  for (const frame of timeline.frames) {
    assert.equal(sha(await readFile(`${root}shared-guarded/${item.name}/${frame.file}`)), frame.sha256);
  }
}
for (const item of await json('change-manifest.json')) {
  assert.equal(sha(await readFile(`${root}${item.output}`)), item.sha256, item.output);
  assert.equal(item.crop.width, 752);
  assert.equal(item.crop.height, 913);
}
for (const path of [
  'flows/flow-fix/chat-app-api-specimens-run4/events.json',
  'flows/flow-fix/chat-app-api-specimens-mobile-run1/events.json',
]) {
  const events = await json(path);
  assert(events.every(event => !event.failure));
  for (const name of ['source pending row', 'incremental response', 'complete resumed response', 'retry completes without another user turn', 'denied tool is visible']) {
    assert(events.some(event => event.name === name), name);
  }
}
const favicon = await json('favicon-runtime-selected/results.json');
assert.deepEqual(favicon.map(row => row.mode), ['live', 'fixture-success', 'fixture-error']);
assert(favicon[1].images.length >= 5);
assert.equal(favicon[2].images.length, 0);
assert(favicon.every(row => row.selectedModelAria.includes('button "Claude Sonnet 4"') && !row.selectedModelAria.includes('Grok 4.5')));
const held = await json('provider-held-pointer/timeline.json');
assert.deepEqual(held.events.map(event => event.type), ['down', 'move', 'up', 'key', 'key']);
assert.equal(held.events[0].button, 'left');
assert.equal(held.events[2].button, 'left');
assert(held.events.every(event => !event.error));
console.log('Verified source and current input hashes, 32 native capture frame sets, 19 derivatives, desktop/mobile chat outcomes, provider decode/selection fixtures, and effective held-pointer events. No exact-parity or native-60-FPS claim.');
