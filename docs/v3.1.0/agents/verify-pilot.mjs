import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_ARTIFACT_ROOT = '/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/pilot-message-defaults-2026-11-05';
const SOURCE_REVISION = '1ab921e62283e788a686bc4bafa1de5ff56104ea';
const WIDGET_BASELINE = '792ad82dca47cdf317fdd94f0bb9251724f562e2';
const INPUT_MANIFEST_SHA256 = '05706f53fe84fe863dc2a4e96155b94d8a497d93fe18987a7a9a1f45145cebae';
const ACQUISITION_REVIEW_SHA256 = 'd4f64e528d9b1ed60f36095b007db3bd16d7bbc3ec7b57e88c091e208fba3547';
const EVENTS_MANIFEST_SHA256 = '1446308d843c48dc1af207d0e7444b775e4b7f64d857e35e88007ef7c7a01a9c';
const ORIGINAL_CONFIG_HASHES = {
  'source-message-mcp.json': '770006a2e04e489cf0a8fc69ee0da050d8c066076756c50940813a2c41cf08f4',
  'source-message-recorder.json': '80aac3f9d527d9fabc9e4aaee6dcecb4805b4830208d7748acc0fe910fb0b162',
  'before-message-mcp.json': 'a011e961c1934a38f90cd34c608331790d79ea5356f92d8b9cab1dff2dd50cad',
  'before-message-recorder.json': '40e7fa73f0365f377e09d919cdacb75b1496ed074e0c66226adf6c41e4b1fd2b',
  'source-message-bubble-mcp.json': '56a584aeca4537930727d9a4f8e85c261dcab23bb57c34764e858f916dce76e8',
  'source-message-bubble-recorder.json': 'a625e460b4f0fc7e2e3c09c4d19b71be03c831be95759085bb3cb15707d26973',
  'before-message-bubble-mcp.json': 'cfb9fdcc2adedd4483a1c1083f29a33c45c6c54dcc2bad5a91e450e5a86470a3',
  'before-message-bubble-recorder.json': '94b983a490298a020b58559094397971ec9bfcedbfda505a5937d815d2deba8c',
  'source-tool-approval-mcp.json': 'ead2c4f1cca0cfb9471ce20cd7472354e8ca6a0a64b7dfb991a8b6aed791ed7e',
  'source-tool-approval-recorder.json': '2565f5f8ebfa19641e6a0cccc74babc80a798fea827ccf4cc25d87155b44d77f',
  'before-tool-approval-mcp.json': '64c45d027a9ff13436652ec7a253f8efee0a481e01f47645ab13c63d8d5d04d7',
  'before-tool-approval-recorder.json': 'fd94f81a28f65b876872128e97a6a2a165ab3687347f086585bd9064f1f7bdf5',
};

function artifactRootFromArgs(args) {
  let root = DEFAULT_ARTIFACT_ROOT;
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] !== '--artifact-root' || !args[index + 1] || args[index + 1].startsWith('--')) {
      throw new Error('Usage: node docs/v3.1.0/agents/verify-pilot.mjs [--artifact-root PATH]');
    }
    root = path.resolve(args[index + 1]);
    index += 1;
  }
  return root;
}

const artifactRoot = artifactRootFromArgs(process.argv.slice(2));
const taskRoot = path.resolve(artifactRoot, '../..');
const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const pilotManifestPath = path.join(repositoryRoot, 'docs/v3.1.0/agents/PILOT_MANIFEST.json');
const issues = [];

const fail = (label, detail) => issues.push(`${label}: ${detail}`);
const read = (file, label = file) => {
  try {
    return readFileSync(file);
  } catch (error) {
    fail(label, `missing/unreadable (${error.code ?? error.message})`);
    return undefined;
  }
};
const readJson = (file, label = file) => {
  const bytes = read(file, label);
  if (!bytes) return undefined;
  try {
    return JSON.parse(bytes.toString('utf8'));
  } catch (error) {
    fail(label, `invalid JSON (${error.message})`);
    return undefined;
  }
};
const hashBytes = bytes => createHash('sha256').update(bytes).digest('hex');
const hashFile = (file, label = file) => {
  const bytes = read(file, label);
  return bytes ? hashBytes(bytes) : undefined;
};
const expect = (condition, label, detail) => {
  if (!condition) fail(label, detail);
};
const expectEqual = (actual, expected, label) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    fail(label, `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
};
const verifyHash = (file, expected, label) => {
  const actual = hashFile(file, label);
  if (actual !== undefined && actual !== expected) fail(label, `SHA-256 mismatch (expected ${expected}, got ${actual})`);
  return actual;
};

const pilotManifest = readJson(pilotManifestPath, 'PILOT_MANIFEST.json');
const inputManifestPath = path.join(artifactRoot, 'manifest.json');
const inputManifest = readJson(inputManifestPath, 'immutable manifest.json');
const acquisitionPath = path.join(artifactRoot, 'acquisition-review.json');
const acquisition = readJson(acquisitionPath, 'acquisition-review.json');
const protocolPath = path.join(artifactRoot, 'events-manifest.json');
const protocol = readJson(protocolPath, 'events-manifest.json');

if (pilotManifest) {
  expectEqual(pilotManifest.sourceRevision, SOURCE_REVISION, 'PILOT_MANIFEST source pin');
  expectEqual(pilotManifest.widgetBaseline, WIDGET_BASELINE, 'PILOT_MANIFEST baseline pin');
  expectEqual(pilotManifest.immutableInputManifestSha256, INPUT_MANIFEST_SHA256, 'PILOT_MANIFEST immutable input hash');
  expectEqual(pilotManifest.acquisitionReviewSha256, ACQUISITION_REVIEW_SHA256, 'PILOT_MANIFEST acquisition review hash');
  expectEqual(pilotManifest.captures?.length, 6, 'PILOT_MANIFEST capture count');
}
verifyHash(inputManifestPath, INPUT_MANIFEST_SHA256, 'immutable manifest.json');
verifyHash(acquisitionPath, ACQUISITION_REVIEW_SHA256, 'acquisition-review.json');
verifyHash(protocolPath, EVENTS_MANIFEST_SHA256, 'events-manifest.json');

if (inputManifest) {
  expectEqual(inputManifest.sourceRevision, SOURCE_REVISION, 'input source revision');
  expectEqual(inputManifest.widgetBaseline, WIDGET_BASELINE, 'input widget baseline');
  expectEqual(inputManifest.viewport, { width: 1280, height: 1000 }, 'input viewport');
  expectEqual(inputManifest.theme, 'dark', 'input theme');
  expectEqual(inputManifest.reducedMotion, 'no-preference', 'input reduced-motion setting');
  expectEqual(inputManifest.units?.length, 6, 'input unit count');
  for (const [name, digest] of Object.entries(ORIGINAL_CONFIG_HASHES)) {
    verifyHash(path.join(artifactRoot, name), digest, `original config ${name}`);
  }
}

if (acquisition) {
  expectEqual(acquisition.sourceRevision, SOURCE_REVISION, 'review source revision');
  expectEqual(acquisition.widgetBaseline, WIDGET_BASELINE, 'review widget baseline');
  expectEqual(acquisition.immutableInputsSha256, INPUT_MANIFEST_SHA256, 'review immutable-input hash');
  expectEqual(acquisition.protocolSha256, EVENTS_MANIFEST_SHA256, 'review protocol hash');
  expectEqual(acquisition.captures?.length, 6, 'review capture count');
  expect(typeof acquisition.acquisition === 'string' && acquisition.acquisition.length > 0, 'review acquisition statement', 'missing');
  expect(typeof acquisition.fidelity === 'string' && /NOT CERTIFIED/i.test(acquisition.fidelity), 'review fidelity limitation', 'must remain explicitly uncertified');
}

const baselineJsPath = path.join(taskRoot, 'baseline-792ad82d-lucide1.67.0/web/main.dart.js');
if (inputManifest?.baselineJavascriptSha256) {
  verifyHash(baselineJsPath, inputManifest.baselineJavascriptSha256, 'unchanged baseline main.dart.js');
}
expectEqual(inputManifest?.baselineJavascriptSha256, 'dd5063b7790b0a65917655b40139ba4a1ef595f59b1b0b681c38650e85aab28c', 'recorded baseline JavaScript SHA-256');

const protocolEntries = protocol?.entries ?? [];
expectEqual(protocolEntries.length, 6, 'event protocol entry count');
const expectedIds = ['source-message', 'before-message', 'source-message-bubble', 'before-message-bubble', 'source-tool-approval', 'before-tool-approval'];
expectEqual(protocolEntries.map(entry => entry.id), expectedIds, 'event protocol order/ids');
expectEqual(acquisition?.captures?.map(row => row.id), expectedIds, 'acquisition capture order/ids');
expectEqual(pilotManifest?.captures?.map(row => row.id), expectedIds, 'compact manifest capture order/ids');

const checkedCaptures = [];
for (const id of expectedIds) {
  const eventEntry = protocolEntries.find(entry => entry.id === id);
  const reviewCapture = acquisition?.captures?.find(row => row.id === id);
  const compactCapture = pilotManifest?.captures?.find(row => row.id === id);
  if (!eventEntry || !reviewCapture || !compactCapture) {
    fail(id, 'capture row missing from one or more manifests');
    continue;
  }

  const configPath = path.join(artifactRoot, `${id}-events.json`);
  const outputDir = path.join(artifactRoot, `${id}-timed`);
  expectEqual(path.basename(eventEntry.config), `${id}-events.json`, `${id} event config path`);
  expectEqual(path.basename(eventEntry.output), `${id}-timed`, `${id} output path`);
  const configHash = verifyHash(configPath, eventEntry.sha256, `${id} event config`);
  expectEqual(reviewCapture.configSha256, configHash, `${id} review config hash`);
  const config = readJson(configPath, `${id} event config`);
  const timeline = readJson(path.join(outputDir, 'timeline.json'), `${id} timeline`);
  const environment = readJson(path.join(outputDir, 'environment.json'), `${id} environment`);
  const scripts = readJson(path.join(outputDir, 'scripts.json'), `${id} served scripts manifest`);
  const ffprobe = readJson(path.join(outputDir, 'ffprobe.json'), `${id} recorded FFprobe`);

  const stillRelative = `${id}-mcp/frame_000.png`;
  const stillPath = path.join(artifactRoot, stillRelative);
  const videoRelative = `${id}-timed/capture.mp4`;
  const videoPath = path.join(artifactRoot, videoRelative);
  expectEqual(path.join(path.basename(path.dirname(reviewCapture.still?.path ?? '')), path.basename(reviewCapture.still?.path ?? '')), stillRelative, `${id} still path`);
  expectEqual(path.join(path.basename(path.dirname(reviewCapture.video?.path ?? '')), path.basename(reviewCapture.video?.path ?? '')), videoRelative, `${id} video path`);
  const stillHash = verifyHash(stillPath, compactCapture.stillSha256, `${id} MCP still`);
  const videoHash = verifyHash(videoPath, compactCapture.videoSha256, `${id} compositor video`);
  expectEqual(reviewCapture.still?.sha256, stillHash, `${id} review still hash`);
  expectEqual(reviewCapture.still?.blank, false, `${id} nonblank still receipt`);
  expectEqual(reviewCapture.video?.sha256, videoHash, `${id} review video hash`);

  const mcpResult = readJson(path.join(artifactRoot, `${id}-mcp-result.json`), `${id} MCP result`);
  expectEqual(mcpResult?.isError, false, `${id} MCP result status`);
  const mcpText = mcpResult?.content?.find(block => block.type === 'text')?.text;
  let mcpReceipt;
  try {
    mcpReceipt = JSON.parse(mcpText);
  } catch {
    fail(`${id} MCP result`, 'missing or invalid text receipt');
  }
  expectEqual(mcpReceipt?.blank, false, `${id} MCP nonblank receipt`);
  expectEqual(mcpReceipt?.count, 1, `${id} MCP still count`);
  expectEqual(path.join(path.basename(path.dirname(mcpReceipt?.frames?.[0] ?? '')), path.basename(mcpReceipt?.frames?.[0] ?? '')), stillRelative, `${id} MCP still path`);

  if (config && timeline) {
    expectEqual(timeline.stats?.backend, 'compositor', `${id} recorder backend`);
    expectEqual(timeline.stats?.errors, [], `${id} recorder errors`);
    expectEqual(timeline.stats?.video?.decodedFrames, timeline.frames?.length, `${id} timeline decoded-frame count`);
    expect(timeline.frames?.length > 1, `${id} recorded frame count`, 'must be greater than one');
    expectEqual(reviewCapture.video?.frames, timeline.frames?.length, `${id} review frame count`);
    expectEqual(compactCapture.decodedFrames, timeline.frames?.length, `${id} compact decoded-frame count`);
    expectEqual(config.events?.length, timeline.events?.length, `${id} dispatched event count`);
    for (const [index, event] of (timeline.events ?? []).entries()) {
      const eventLabel = `${id} event ${index + 1}`;
      expect(Number.isFinite(event.dispatchBeforeMs), eventLabel, 'missing dispatchBeforeMs');
      expect(Number.isFinite(event.dispatchAfterMs) && event.dispatchAfterMs >= event.dispatchBeforeMs, eventLabel, 'invalid dispatchAfterMs');
      expectEqual(event.error, undefined, `${eventLabel} error`);
      const expectedEvent = config.events[index];
      for (const key of ['type', 'target', 'text', 'key', 'atMs']) {
        if (expectedEvent?.[key] !== undefined) expectEqual(event[key], expectedEvent[key], `${eventLabel} ${key}`);
      }
    }
    const sortedFrames = [...timeline.frames].sort((left, right) => left.metadata.timestamp - right.metadata.timestamp);
    for (let index = 0; index < sortedFrames.length; index += 1) {
      const frame = sortedFrames[index];
      const framePath = path.join(outputDir, frame.file);
      verifyHash(framePath, frame.sha256, `${id} original frame ${frame.file}`);
      if (index > 0) expect(frame.metadata.timestamp > sortedFrames[index - 1].metadata.timestamp, `${id} frame timestamps`, `not strictly increasing at ${frame.file}`);
    }

    if (environment) {
      expectEqual(environment.viewport, inputManifest?.viewport, `${id} environment viewport`);
      expectEqual(environment.reducedMotion, false, `${id} effective reduced motion`);
      expectEqual(environment.requestedReducedMotion, inputManifest?.reducedMotion, `${id} requested motion preference`);
      expectEqual(environment.provenance?.pinnedSource, SOURCE_REVISION, `${id} environment source pin`);
      if (id.startsWith('before-')) {
        expectEqual(environment.flutter, true, `${id} Flutter environment`);
        expectEqual(environment.flutterCapture?.disableAnimations, false, `${id} Flutter reduced-motion flag`);
      } else {
        expectEqual(environment.flutter, false, `${id} source environment`);
        expect(/\bdark\b/.test(environment.htmlClass ?? ''), `${id} effective source theme`, 'dark class missing');
      }
    }

    if (scripts) {
      expect(scripts.length > 0, `${id} served scripts manifest`, 'empty');
      for (const script of scripts) {
        expectEqual(script.status, 200, `${id} script HTTP status ${script.url}`);
        expect(Number.isInteger(script.bytes) && script.bytes > 0, `${id} script byte count ${script.url}`, 'missing or empty');
        expect(/^[a-f0-9]{64}$/.test(script.sha256), `${id} script SHA-256 ${script.url}`, 'invalid digest');
        const url = new URL(script.url);
        const relativeUrl = decodeURIComponent(url.pathname).replace(/^\/+/, '');
        const originalCandidates = id.startsWith('source-')
          ? [path.join(taskRoot, 'source-1ab921e6', relativeUrl), path.join(taskRoot, 'reference-runtime', relativeUrl)]
          : [path.join(taskRoot, 'baseline-792ad82d-lucide1.67.0', 'web', relativeUrl), path.join(taskRoot, 'baseline-792ad82d-lucide1.67.0', relativeUrl)];
        for (const candidate of originalCandidates) {
          if (existsSync(candidate)) verifyHash(candidate, script.sha256, `${id} original served script ${url.pathname}`);
        }
      }
      expectEqual(hashFile(path.join(outputDir, 'scripts.json'), `${id} served scripts manifest`), reviewCapture.scriptsSha256, `${id} served scripts manifest hash`);
      if (environment?.servedJs) {
        const matchingScript = scripts.find(script => script.url === environment.servedJs.url);
        expect(Boolean(matchingScript), `${id} servedJs manifest entry`, 'not present in scripts.json');
        expectEqual(matchingScript?.sha256, environment.servedJs.sha256, `${id} servedJs hash`);
        if (id.startsWith('source-')) {
          expectEqual(environment.servedJs.revision, SOURCE_REVISION, `${id} servedJs source revision`);
        } else {
          expectEqual(environment.servedJs.revision, WIDGET_BASELINE, `${id} servedJs baseline revision`);
          expectEqual(environment.servedJs.sha256, inputManifest?.baselineJavascriptSha256, `${id} served baseline JavaScript hash`);
        }
      }
    }
  }

  if (ffprobe) {
    const recordedDecodedCount = ffprobe.streams?.find(stream => stream.codec_type === 'video')?.nb_read_frames;
    const ffprobeFramesLength = ffprobe.frames?.filter(frame => frame.media_type === 'video').length;
    const count = Number(recordedDecodedCount ?? ffprobeFramesLength);
    expect(Number.isInteger(count) && count > 0, `${id} recorded FFprobe decoded count`, 'missing/invalid');
    expectEqual(count, compactCapture.decodedFrames, `${id} FFprobe count vs compact manifest`);
    expectEqual(count, timeline?.stats?.video?.decodedFrames, `${id} FFprobe count vs timeline stats`);
  }

  expectEqual(reviewCapture.timelineSha256, hashFile(path.join(outputDir, 'timeline.json'), `${id} timeline`), `${id} review timeline hash`);
  expectEqual(reviewCapture.environmentSha256, hashFile(path.join(outputDir, 'environment.json'), `${id} environment`), `${id} review environment hash`);
  const finalFrameRelative = path.join(path.basename(path.dirname(path.dirname(reviewCapture.finalFrame ?? ''))), 'original-frames', path.basename(reviewCapture.finalFrame ?? ''));
  expectEqual(finalFrameRelative, path.join(`${id}-timed`, 'original-frames', path.basename(reviewCapture.finalFrame ?? '')), `${id} final frame path`);
  const timelineFinalFrame = timeline?.frames?.reduce((latest, frame) => !latest || frame.metadata.timestamp > latest.metadata.timestamp ? frame : latest, undefined);
  expectEqual(path.basename(reviewCapture.finalFrame ?? ''), path.basename(timelineFinalFrame?.file ?? ''), `${id} reviewed final frame matches last recorded frame`);
  checkedCaptures.push({ id, stillSha256: stillHash, videoSha256: videoHash, decodedFrames: compactCapture.decodedFrames });
}

for (const [file, expected] of [
  ['after-focused-tests.log', pilotManifest?.regressionGate?.afterLogSha256],
  ['after-root-analyze.log', pilotManifest?.analysis?.rootLogSha256],
  ['after-example-analyze.log', pilotManifest?.analysis?.exampleLogSha256],
  ['static-diagnostic-result.log', pilotManifest?.actualMcpDiagnostics?.staticLogSha256],
  ['motion-diagnostic-result.log', pilotManifest?.actualMcpDiagnostics?.motionLogSha256],
  ['message-bubble-source-before-roi/selection.json', pilotManifest?.actualMcpDiagnostics?.selectionSha256],
]) {
  expect(/^[a-f0-9]{64}$/.test(expected ?? ''), file, 'receipt hash missing');
  verifyHash(path.join(artifactRoot, file), expected, file);
}

if (issues.length > 0) {
  console.error(`ISSUES (${issues.length})`);
  for (const issue of issues) console.error(`- ${issue}`);
  process.exitCode = 1;
} else {
  console.log(`PASS: read-only acquisition receipts verified (${checkedCaptures.length} stills, ${checkedCaptures.length} videos and original frame hashes).`);
  console.log('No state, fidelity, timing, or performance pass is implied; consult PILOT.md for manual state review and remaining gates.');
}
