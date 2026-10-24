import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('./', import.meta.url));
const recorder = '/Users/codenameakshay/.t3/worktrees/beui/t3-655688e6/tool/parity_capture.mjs';
const sha = value => createHash('sha256').update(value).digest('hex');
const phase = process.argv[2] ?? 'probed';
const selected = process.argv[3];
const captureRoot = `${root}shared-guarded${phase === 'probed' ? '' : `-${phase}`}`;
const build = `example/build/agents-round2-${phase}/main.dart.js`;
const inventory = JSON.parse(await readFile(`${root}../route-inventory.json`));
const examples = {
  'message-bubble': ['avatars', 'show-more'],
  'loading-states': ['thinking-shimmer', 'agent-progress'],
  'agent-activity': ['reasoning-steps', 'web-search', 'tool-calls', 'mixed-activity', 'agent-trace'],
  'tool-result': ['request-result'],
  'approval-card': ['review'],
};
const batches = inventory.routes.map(r => ({ slug: r.slug }));
for (const [slug, names] of Object.entries(examples)) {
  for (const example of names) batches.push({ slug, example });
}
batches.push({ slug: 'prompt-input', reducedMotion: 'reduce', width: 592 });
batches.push({ slug: 'voice-orb', reducedMotion: 'reduce', width: 592 });
await mkdir(captureRoot);
const results = [];
for (const item of batches) {
  if (selected && item.slug !== selected) continue;
  const reducedMotion = item.reducedMotion ?? 'no-preference';
  const name = `${item.slug}${item.example ? `-${item.example}` : ''}${reducedMotion === 'reduce' ? '-reduced' : ''}`;
  const width = item.width ?? 752;
  const url = `http://127.0.0.1:18107/agents-round2-${phase}/?slug=${item.slug}&theme=dark&previewWidth=${width}&captureProbe=1${item.example ? `&example=${item.example}` : ''}`;
  const expected = sha(await readFile(build));
  const scriptUrl = new URL('main.dart.js', url).href;
  const actual = sha(Buffer.from(await (await fetch(scriptUrl)).arrayBuffer()));
  assert.equal(actual, expected, `Wrong served build before ${name}`);
  const config = {
    url, theme: 'dark', viewport: { width: 1440, height: 1000 },
    reducedMotion, backend: 'screenshots', requireFlutterProbe: true,
    servedJs: { url: scriptUrl, sha256: expected, revision: '9fc8919 plus round-two owned changes, probed frozen build' },
    stageSelector: 'flutter-view', targets: {}, events: [],
    loadWaitMs: 1500, finalHoldMs: item.example ? 4500 : 2200,
    provenance: {
      wrapper: 'example/lib/demos/agents_capture.dart',
      widthRequested: width, noMotionOverride: true,
      recorder, recorderSha256: sha(await readFile(recorder)),
      probe: 'Agent-owned copy of d831524 shared observation schema. Shared shell and theme untouched.',
      sourceRevision: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05',
      sourceLiveRevision: 'unknown', stateClaim: 'Idle only. No interaction assertion.',
    },
  };
  const configPath = `${captureRoot}/${name}.config.json`;
  await writeFile(configPath, JSON.stringify(config, null, 2));
  const result = spawnSync(process.execPath, [recorder, configPath, `${captureRoot}/${name}`], {
    env: { ...process.env, PARITY_PLAYWRIGHT: '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs' },
    encoding: 'utf8', maxBuffer: 8 * 1024 * 1024,
  });
  await writeFile(`${captureRoot}/${name}.log`, result.stdout + result.stderr);
  results.push({ ...item, name, reducedMotion, sha256: expected, status: result.status });
  await writeFile(`${captureRoot}/results.json`, JSON.stringify(results, null, 2));
  console.log(name, result.status);
}
assert(results.every(r => r.status === 0), 'One or more guarded captures failed. See retained logs.');
