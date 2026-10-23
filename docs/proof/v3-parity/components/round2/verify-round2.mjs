import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join, dirname, relative } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = import.meta.dirname;
const json = async path => JSON.parse(await readFile(path));
const presentations = await json(join(root, 'presentations/index.json'));
assert.equal(presentations.length, 36);
assert.equal(new Set(presentations.map(item => item.slug)).size, 18);
const records = [];
const checkedRuns = new Set();
async function verifyRecording(run) {
  if (checkedRuns.has(run)) return;
  const config = await json(join(run, 'record-config.json'));
  const timeline = await json(join(run, 'recording/timeline.json'));
  const scripts = await json(join(run, 'recording/scripts.json'));
  assert(scripts.some(script => script.url === config.servedJs.url && script.status === 200 && script.sha256 === config.servedJs.sha256), 'Actual loaded response matches frozen JavaScript');
  assert.equal(timeline.events.length, config.events.length);
  for (const [index, event] of timeline.events.entries()) assert.equal(event.type, config.events[index].type);
  for (const frame of timeline.frames) {
    const bytes = await readFile(join(run, 'recording', frame.file));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), frame.sha256, `${run} original PNG ${frame.index}`);
  }
  checkedRuns.add(run);
}
for (const item of presentations) {
  const run = dirname(dirname(join(root, item.after)));
  const config = await json(join(run, 'record-config.json'));
  const environment = await json(join(run, 'recording/environment.json'));
  const timeline = await json(join(run, 'recording/timeline.json'));
  await verifyRecording(run);
  assert.equal(environment.flutterCapture.disableAnimations, false);
  assert.equal(environment.requestedReducedMotion, 'no-preference');
  assert.equal(config.provenance.recorderHash, '2aa405da2051b7a59a3010f7b0e3291108e3c51c65f6e1e76bf73bca120709ca');
  assert.equal(config.servedJs.sha256, config.provenance.jsHash);
  assert.equal(timeline.stats.video.decodedFrames, timeline.stats.frames);
  assert.equal(timeline.stats.errors.length, 0);
  const decoded = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=nb_read_frames', '-of', 'json', join(root, item.video)], { encoding: 'utf8' });
  assert.equal(decoded.status, 0);
  assert.equal(JSON.parse(decoded.stdout).streams[0].nb_read_frames, item.decoded.streams[0].nb_read_frames);
  records.push({ slug: item.slug, theme: item.theme, run: relative(root, run), revision: config.provenance.revision, jsHash: config.servedJs.sha256, measuredFps: timeline.stats.measuredFps, maxIntervalMs: timeline.stats.maxIntervalMs, frames: timeline.stats.frames, coverage: item.coverage });
}

const outcomes = [];
const changed = ['adaptive-stepper', 'alert', 'breadcrumb', 'color-picker', 'color-selector', 'combobox', 'date-range-picker', 'image-viewer', 'tooltip'];
for (const theme of ['light', 'dark', 'reduce']) {
  for (const slug of changed) {
    let batch = 'functional-final';
    if (['breadcrumb', 'combobox'].includes(slug)) batch = 'final-repairs';
    if (slug === 'tooltip') batch = 'final-controls';
    if (slug === 'color-picker' && theme === 'light') batch = 'functional-final-corrected';
    const run = join(root, batch, `candidate-${theme === 'reduce' ? 'light-reduce' : `${theme}-no-preference`}-${slug}`);
    const observations = await json(join(run, 'observed.json'));
    const environment = await json(join(run, 'recording/environment.json'));
    await verifyRecording(run);
    assert.equal(environment.flutterCapture.disableAnimations, theme === 'reduce');
    assert.equal(environment.reducedMotion, theme === 'reduce');
    const state = label => {
      const result = observations.find(item => item.label === label);
      assert(result, `${slug} observed ${label}`);
      return result;
    };
    const has = (label, name) => state(label).controls.some(control => control.label === name);
    const value = (label, text) => state(label).controls.some(control => control.value === text);
    let result;
    if (slug === 'adaptive-stepper') {
      for (const [label, number] of [['rest', 2], ['maximum', 3], ['reverse', 2], ['one', 1], ['minimum', 0], ['leave-minimum', 1]]) {
        const values = state(label).text.trim().split(/\s+/);
        assert(values.length > 0 && values.every(value => value === String(number)), `${slug} ${label} displays ${number}`);
      }
      result = 'Observed values 2,3,2,1,0,1. Silhouette/timing require visual review.';
    } else if (slug === 'alert') {
      assert(has('success', 'Dismiss alert'));
      assert(!has('dismissed', 'Dismiss alert'));
      assert(has('reopened', 'Dismiss alert'));
      result = 'Dismiss control disappears and returns on reopen. Tone/title pixels are retained screenshots, not DOM assertions.';
    } else if (slug === 'breadcrumb') {
      assert(has('overflow-open', 'Projects'));
      assert.match(state('release-hidden-route').text, /Current page Navigation/);
      assert.match(state('parent-navigation').text, /Current page Workspace/);
      assert.match(state('forward-navigation').text, /Current page Projects/);
      result = 'Stable hover popup. Held Projects released after Escape leaves Navigation unchanged. Workspace then Projects navigation succeeds.';
    } else if (slug === 'color-picker') {
      assert(has('spectrum-held', '#3a60a6'));
      assert(has('spectrum-drag', '#265cbf'));
      assert(has('rgb-channels', 'RGB'));
      assert(has('hsl-channels', 'HSL'));
      assert(!has('picker-dismissed', 'HSL'));
      result = 'Measured spectrum coordinates produce source-matching #3a60a6 and #265cbf. HEX to RGB to HSL, then Escape. Editable hex case has separate widget tests.';
    } else if (slug === 'color-selector') {
      for (const [label, name] of [['rest', 'Blue'], ['selected-ring-held', 'Blue'], ['purple-selected', 'Purple'], ['keyboard-next', 'Pink']]) assert(state(label).controls.some(control => control.label === name && control.checked === 'true'));
      result = 'Checked state Blue, held Blue, Purple, then keyboard Pink. Ring press geometry has focused widget coverage and held screenshot.';
    } else if (slug === 'combobox') {
      assert(value('query-product', 'Product'));
      assert(!state('query-product').text.includes('24 experiments'));
      assert(value('option-selected', 'Product team'));
      result = 'Native Product query accepted, unmatched Playground filtered out, Product team selected.';
    } else if (slug === 'date-range-picker') {
      assert(has('calendar-dismissed', 'Reporting period: Oct 16 – Oct 17, 2026'));
      result = 'Keyboard range selection updates trigger to Oct 16 – Oct 17, 2026, without weekday.';
    } else if (slug === 'image-viewer') {
      assert(has('zoomed', 'Zoom out'));
      assert.match(state('swipe-page').text, /2 of 3/);
      assert.match(state('keyboard-previous').text, /1 of 3/);
      assert(!has('release-hidden-zoom', 'Zoom out'));
      assert(!has('release-hidden-zoom', 'Close viewer'));
      result = 'Zoom mode changes, swipe advances to 2/3, ArrowLeft returns to 1/3, Escape plus held release leaves modal closed. Pan pixels and focus return require retained screenshots/focused tests.';
    } else {
      assert.match(state('held-mouse-release').focus.text, /Top$/);
      assert.match(state('tab-after-click').focus.text, /Left$/);
      assert(state('top-hover').text.endsWith('\nMore context'));
      assert(!state('no-generic-reopen').text.endsWith('\nMore context'));
      result = '800ms mouse hold preserves child focus on release. Click then Tab focuses Left. Escape then unrelated key does not reopen.';
    }
    outcomes.push({ slug, preference: theme, run: relative(root, run), result, verdict: 'listed assertions passed; not a complete parity verdict' });
  }
}
const manifest = { presentations: records, outcomes, fastMotion: 'inconclusive; native60fps unavailable', goldenGate: 'failed; unchanged artifacts and exact log are under verification' };
await writeFile(join(root, 'verification/browser-outcomes.json'), JSON.stringify(manifest, null, 2));
console.log(JSON.stringify({ presentations: records.length, functionalSequences: outcomes.length, verdict: 'All listed functional assertions and decoded-frame checks passed. Exact parity not claimed.' }));
