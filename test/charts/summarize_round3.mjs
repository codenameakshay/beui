import {readdir, readFile, writeFile, mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join, resolve} from 'node:path';
import assert from 'node:assert/strict';

const [captureRoot, newReport] = process.argv.slice(2);
if (!captureRoot || !newReport) throw Error('Usage: node test/charts/summarize_round3.mjs CAPTURE_ROOT NEW_REPORT_DIRECTORY');
const root = resolve(captureRoot);
const report = resolve(newReport);
await mkdir(report);
const readout = {
  'liquidity-heatmap': 'Size uses the source 350ms ticker. Dates and market labels are static.',
  'returns-calendar': 'Return uses the source 350ms ticker. Month-first title is static.',
  'heat-calendar': 'Count uses the source 350ms ticker. UTC date has no invented year.',
  'status-bar': 'Date, status, and description are source-static. No numeric ticker.',
  treemap: 'Value and share use source 200ms tickers. Ancestor path and title are separate.',
  'order-book': 'Native price focus updates the inline cumulative summary. Source has no Tooltip.',
  'price-target-fan': 'Header animates. Tooltip date, price, analysts, and vs-now metrics are source-static.',
  'donut-chart': 'Center uses directional DigitSwap. Caption slides and fades. It is not a numeric ticker.',
};
const stamp = ms => {
  const value = Math.max(0, Math.round(ms));
  return `${String(Math.floor(value / 3600000)).padStart(2, '0')}:${String(Math.floor(value / 60000) % 60).padStart(2, '0')}:${String(Math.floor(value / 1000) % 60).padStart(2, '0')},${String(value % 1000).padStart(3, '0')}`;
};
const inventory = [];
for (const entry of await readdir(root, {withFileTypes: true})) {
  if (!entry.isDirectory()) continue;
  const directory = join(root, entry.name);
  let timeline;
  try {timeline = JSON.parse(await readFile(join(directory, 'timeline.json'), 'utf8'));}
  catch {continue;}
  const config = JSON.parse(await readFile(join(directory, 'config.json'), 'utf8'));
  const environment = JSON.parse(await readFile(join(directory, 'environment.json'), 'utf8'));
  const probe = JSON.parse(await readFile(join(directory, 'ffprobe.json'), 'utf8'));
  const frames = timeline.frames;
  for (const frame of frames) {
    const bytes = await readFile(join(directory, frame.file));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), frame.sha256, `${entry.name} ${frame.file}`);
  }
  assert.equal(Number(probe.streams[0].nb_read_frames), frames.length);
  if (config.servedJs) {
    if (config.requireFlutterProbe) assert.equal(environment.flutterCapture.disableAnimations, config.reducedMotion === 'reduce');
    const scripts = JSON.parse(await readFile(join(directory, 'scripts.json'), 'utf8'));
    assert(scripts.some(script => script.url === config.servedJs.url && script.sha256 === config.servedJs.sha256));
  }
  const first = frames[0].metadata
    ? frames[0].metadata.timestamp * 1000 - timeline.stats.originEpochMs
    : frames[0].receivedMs;
  const events = timeline.events.filter(event => event.dispatchBeforeMs !== undefined);
  const duration = timeline.stats.durationMs;
  const srt = [];
  const slug = config.provenance?.slug ?? config.slug;
  for (let i = 0; i < events.length; i++) {
    const event = events[i];
    const start = event.dispatchBeforeMs - first;
    const end = i + 1 < events.length ? events[i + 1].dispatchBeforeMs - first : duration;
    const identity = event.target === 'A' || event.target === 'B'
      ? slug === 'status-bar'
        ? `API period ${event.target === 'A' ? '1, 2026-08-21, Aug 21' : '2, 2026-08-22, Aug 22'}. Operational. All checks passed`
        : config.provenance.observedProbeTargets[event.target === 'A' ? 0 : 1].name.split('\n')[0]
      : typeof event.target === 'number' ? environment.targets[event.target]?.name : null;
    let caption = identity ? `${event.caption ?? event.target} ${identity}.` : event.caption;
    if (event.type === 'key') caption = `Actual ${event.key}. ${event.caption ?? ''}`;
    if (i === 0) caption += ` ${config.servedJs || config.reference ? readout[slug] : 'Before implementation. Legacy wrapper and recorder, no effective Flutter motion probe.'} ${config.theme}. ${config.reducedMotion ?? 'legacy motion config'}.`;
    srt.push(`${i + 1}\n${stamp(start)} --> ${stamp(end)}\n${caption}\n`);
  }
  await writeFile(join(directory, 'captions.srt'), srt.join('\n'), {flag: 'wx'});
  const stills = [650, 1150, 1280, 1750, 2300, 3200, 3700].map(atMs => ({
    atMs,
    frame: frames.find(frame => frame.receivedMs >= (timeline.stats.sequenceStartMs ?? first) + atMs)?.file ?? frames.at(-1).file,
  }));
  inventory.push({name: entry.name, config: config.provenance, requested: {viewport: config.viewport, reducedMotion: config.reducedMotion}, effective: {viewport: environment.viewport, dpr: environment.dpr, browserReduce: environment.reducedMotion, flutter: environment.flutterCapture ?? null, nativeVideo: {width: probe.streams[0].width, height: probe.streams[0].height}}, stats: timeline.stats, framesHashed: frames.length, videoSha256: createHash('sha256').update(await readFile(join(directory, 'capture.mp4'))).digest('hex'), stills});
}
await writeFile(join(report, 'inventory.json'), JSON.stringify(inventory, null, 2));
await writeFile(join(report, 'README.md'), `# Recording integrity\n\nVerified ${inventory.length} recordings and ${inventory.reduce((sum, item) => sum + item.framesHashed, 0)} original PNG hashes. Every video decoded to its original frame count. Shared-recorder candidates verify script-response hashes and effective Flutter reduced-motion values. Legacy before captures have no effective Flutter probe. Source deployment revisions remain unknown.\n\nThe sidecar captions use actual input dispatch times relative to the first delivered frame. Dispatch is not a claim that the resulting UI state passed. Native dimensions are recorded separately from CSS viewport size. Short-motion timing remains inconclusive.\n`);
console.log(JSON.stringify({recordings: inventory.length, originalFrames: inventory.reduce((sum, item) => sum + item.framesHashed, 0), fpsRange: [Math.min(...inventory.map(item => item.stats.measuredFps)), Math.max(...inventory.map(item => item.stats.measuredFps))]}, null, 2));
