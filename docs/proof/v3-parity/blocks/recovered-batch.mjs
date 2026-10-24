import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const tool = '/Users/codenameakshay/.t3/worktrees/beui/t3-6e9ab891/tool/parity_capture.mjs';
const expected = process.env.EXPECTED_JS_SHA256 || 'aea97a92218d9462a95d601dde72b6bc9e4fee1c060ea4730967aa05fdaf1bbb';
const batch = process.argv[2] || 'recovered-dark';
const output = path.join(root, batch);
await mkdir(output);
const url = 'http://127.0.0.1:8103/main.dart.js';
const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
const actual = createHash('sha256').update(Buffer.from(await response.arrayBuffer())).digest('hex');
await writeFile(path.join(output, 'served-build.json'), JSON.stringify({
  url, checkedAt: new Date().toISOString(), expected, actual, match: actual === expected,
  codeHead: process.env.CODE_HEAD || '34e2fc756e6bf5da84b521c48eabe37148d36c99',
  baseline: '5ec78ac30e1274727ddd185a883346e4d908e6c8',
  sourceCheckout: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05',
}, null, 2));
if (actual !== expected) throw new Error(`Foreign release ${actual}`);

const cases = [
  { slug: 'card-folder', labels: ['Show card details', 'Open Saurabh Chauhan, card ending in 0806, expires 08/29'],
    events: [[600, 'move', 0], [1000, 'click', 0], [1700, 'click', 0], [2400, 'click', 1], [3100, 'key', 'Enter'], [3800, 'move', 'outside']] },
  { slug: 'morphing-tabs', labels: ['General', 'Room 2', 'Close Archive'],
    events: [[600, 'move', 0], [1000, 'click', 0], [1700, 'key', 'ArrowRight'], [2400, 'key', 'ArrowLeft'], [3100, 'click', 2], [3800, 'move', 'outside']] },
  { slug: 'prediction-market-card', labels: ['Trade Celtics at 51%', 'Trade Lakers at 49%', '2.0×', 'Update odds'], sourceLabels: ['Trade Celtics at 51%', 'Trade Lakers at 49%', 'Potential payout for Celtics', 'Update odds'],
    events: [[600, 'move', 0], [1200, 'move', 1], [1800, 'move', 2], [2400, 'move', 'outside'], [3000, 'click', 1], [3400, 'key', 'Enter'], [4000, 'click', 3]] },
  { slug: 'number', labels: ['Animate'], sourceLabels: ['Animate card number'],
    events: [[600, 'click', 0], [1300, 'click', 0], [1600, 'click', 0], [2400, 'key', 'Enter'], [3300, 'move', 'outside']] },
  { slug: 'text-animation', labels: ['Next phrase'],
    events: [[600, 'click', 0], [900, 'click', 0], [1700, 'click', 0], [2800, 'key', 'Enter'], [3600, 'move', 'outside']] },
  { slug: 'project-folder', labels: ['Brand direction'], events: [[600, 'move', 0], [1200, 'move', 'outside'], [1900, 'click', 0], [2700, 'key', 'Escape']] },
  { slug: 'notification-stack', prefixes: true, labels: ['3 notifications. Expand notifications.'], events: [[600, 'move', 0], [1300, 'move', 'outside'], [2000, 'click', 0], [3000, 'key', 'Tab']] },
  { slug: 'dynamic-island', labels: ['Call', 'Timer', 'Music', 'Dismiss'], events: [[600, 'click', 0], [1500, 'click', 1], [2400, 'click', 2], [3300, 'click', 3]] },
  { slug: 'availability-scheduler', labels: ['Add time range to Monday', 'Copy Monday hours to other days'], events: [[600, 'click', 0], [1700, 'click', 1], [2700, 'key', 'Escape']] },
  { slug: 'morphing-search', labels: ['Find components'], events: [[600, 'click', 0], [1200, 'text', 'folder'], [2100, 'key', 'ArrowDown'], [2600, 'key', 'Enter'], [3300, 'key', 'Escape']] },
  { slug: 'morphing-search-chips', labels: ['Search inspiration'], events: [[600, 'click', 0], [1200, 'text', 'dark'], [1900, 'key', 'Enter'], [2700, 'key', 'Escape']] },
  { slug: 'prediction-market', labels: ['Trade Celtics at 51%', 'Trade Lakers at 49%', 'Update odds'], events: [[600, 'move', 0], [1300, 'move', 1], [2000, 'move', 'outside'], [2700, 'click', 2]] },
  { slug: 'wallet-card', labels: ['Hide balance', 'Main Wallet', 'Simulate balance change'], events: [[600, 'click', 0], [1500, 'click', 0], [2400, 'click', 1], [3000, 'key', 'Escape'], [3600, 'click', 2]] },
  { slug: 'bloom-menu', labels: ['Create\nCreate'], events: [[600, 'click', 0], [1500, 'key', 'Escape'], [2300, 'click', 0], [3300, 'click', 'outside']] },
  { slug: 'feedback-widget', labels: ['Help us improve'], events: [[600, 'click', 0], [1500, 'key', 'Escape'], [2300, 'click', 0], [3300, 'key', 'Tab']] },
  { slug: 'dock', labels: ['home', 'music', 'settings'], events: [[600, 'move', 0], [1300, 'move', 1], [2000, 'move', 2], [2800, 'move', 'outside'], [3300, 'click', 0], [3900, 'key', 'Tab']] },
  { slug: 'knockout-bracket', labels: ['Final · Spain v Argentina · 2–1'], events: [[600, 'move', 0], [1600, 'move', 'outside'], [2400, 'click', 0], [3300, 'key', 'Tab']] },
  { slug: 'signup-form', labels: [], events: [[600, 'move', 'stage'], [1600, 'key', 'Tab'], [2600, 'key', 'Tab']] },
  { slug: 'infinite-masonry', labels: [], events: [[600, 'move', 'stage'], [2000, 'move', 'outside']] },
];
for (const item of cases.filter(item => !process.env.SLUGS || process.env.SLUGS.split(',').includes(item.slug))) {
  for (const target of (process.env.TARGETS || 'reference,candidate').split(',')) {
    const candidate = target === 'candidate';
    const sourcePhase = ['number', 'text-animation'].includes(item.slug) ? 'before-motion-routes' : 'before';
    const elements = JSON.parse(await readFile(path.join(root, candidate ? 'after-verified592' : sourcePhase, target, item.slug, 'elements.json')));
    const labels = candidate ? item.labels : item.sourceLabels || item.labels;
    const targets = { outside: { x: 1100, y: 100 }, stage: { x: 770, y: 500 } };
    for (const [index, label] of labels.entries()) {
      const found = elements.filter(e => (e.label === label || e.text === label || e.text === `${label}Close ${label}` || item.prefixes && (e.label || e.text).startsWith(label)) && e.y > 200 && e.y < 850)
        .sort((a, b) => a.width * a.height - b.width * b.height)[0];
      if (!found) throw new Error(`Missing measured ${target}/${item.slug}/${label}`);
      targets[index] = { x: found.x + found.width / 2, y: found.y + found.height / 2, measuredBounds: found };
    }
    const sourceSlug = item.slug === 'prediction-market-card' ? 'prediction-market' : item.slug;
    const config = {
      url: candidate ? `http://127.0.0.1:8103/?slug=${item.slug}&theme=dark&previewWidth=592` : `https://beui.dev/components/${['number', 'text-animation'].includes(item.slug) ? 'motion' : 'blocks'}/${sourceSlug}`,
      viewport: { width: 1280, height: 900 }, theme: 'dark', reference: !candidate,
      backend: 'screenshots', loadWaitMs: 3500, finalHoldMs: 800,
      provenance: { target, expectedCandidateJsSha256: expected, sourceCheckout: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', liveDeploymentRevision: null, baselineWrapperApplied: false, candidatePreviewInnerWidth: candidate ? 592 : null, limitations: 'Route first example only. Coordinates measured from rest screenshot. Inspect observed states and actual captured dimensions. No 60 FPS or parity certification.' },
      targets,
      events: item.events.map(([atMs, type, value]) => type === 'key' ? { atMs, type, key: value } : type === 'text' ? { atMs, type, text: value } : { atMs, type, target: String(value) }),
    };
    const configPath = path.join(output, `${target}-${item.slug}.json`);
    await writeFile(configPath, JSON.stringify(config, null, 2));
    const run = spawnSync(process.execPath, [tool, configPath, path.join(output, `${target}-${item.slug}`)], {
      env: { ...process.env, PARITY_PLAYWRIGHT: '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs' }, encoding: 'utf8', timeout: 180000,
    });
    await writeFile(path.join(output, `${target}-${item.slug}.log`), `${run.stdout || ''}\n${run.stderr || ''}\nexit=${run.status}\nerror=${run.error || ''}\n`);
    console.log(target, item.slug, run.status);
  }
}
