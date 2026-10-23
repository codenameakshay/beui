import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const root = import.meta.dirname;
const recorder = '/Users/codenameakshay/.t3/worktrees/beui/t3-6e9ab891/tool/parity_capture.mjs';
const measurements = JSON.parse(await readFile(join(root, 'release-measurements-run3/measurements.json'), 'utf8'));
measurements.sort((a, b) => (a.slug === 'tooltip' ? -1 : b.slug === 'tooltip' ? 1 : 0));
const output = join(root, 'release-recordings-run2');
await mkdir(output);
await mkdir(join(output, 'configs'));
const changed = new Set(['tooltip', 'timeline', 'alert', 'color-selector', 'arc-picker', 'tabs', 'card', 'breadcrumb', 'image-viewer']);
const choices = {
  tooltip: ['Top', 'Right', 'Top'], alert: ['Success', 'Warning', 'Error', 'Info'],
  collapsible: ['More details', 'More details'], 'aspect-ratio': ['1:1', '16:9'],
  'arc-picker': ['Afternoon', 'Golden hour'], 'sortable-stack': ['Reorder Collect references'],
  'image-viewer': ['Open Sculptural architecture'], 'date-range-picker': [/^Reporting period:/],
  card: ['Signed contract', 'Invoice'], 'color-picker': [/^#3478f6$/i],
  'color-selector': ['Purple', 'Red', 'Blue'], breadcrumb: ['Breadcrumb', 'Workspace'],
  button: ['Continue'], 'expandable-control': ['Notifications', 'React'],
  'adaptive-stepper': ['Increase value', 'Increase value', 'Decrease value'],
  tabs: ['Activity', 'Settings', 'Overview'], combobox: ['Search workspaces'],
  'multi-select': ['Remove Design'], 'shared-layout-bg': [/^Drafts/],
  'animated-sidebar': ['Toggle sidebar'], 'file-tree': ['app'], dock: [/^calendar$/i],
  'text-animation': ['Next phrase'], number: [/^Animate/], 'range-slider': [], table: ['Name', 'Role'], input: [],
};
const runs = [];
for (const origin of ['reference', 'candidate']) {
  for (const theme of ['light', 'dark']) {
    for (const measure of measurements) {
      const slug = measure.slug;
      if (origin === 'reference' && !changed.has(slug)) continue;
      const sample = measure[origin];
      const controls = sample?.controls?.filter(c => !c.disabled && c.x >= 300 && c.y >= 300 && c.y + c.height / 2 < 975 && c.x + c.width / 2 < 1100 && c.width < 500 && c.height < 300) ?? [];
      if (origin === 'reference' && slug === 'color-selector') {
        // Visible label rectangles measured on the live page at this viewport.
        for (const [name, x] of [['Blue', 382], ['Purple', 438], ['Red', 550]]) {
          controls.push({ name, x, y: 498, width: 44, height: 44 });
        }
      }
      const targets = { outside: { x: 300, y: 280 } };
      const events = [];
      const missingTargets = [];
      for (const [index, name] of (choices[slug] ?? []).entries()) {
        const control = controls.find(c => name instanceof RegExp ? name.test(c.name) : [name, name + name, `${name} ${name}`, `${name}\n${name}`].includes(c.name));
        if (!control) { missingTargets.push(String(name)); continue; }
        const target = `control${index}`;
        targets[target] = { x: control.x + control.width / 2, y: control.y + control.height / 2, width: control.width, height: control.height, measuredName: control.name, measuredRole: control.role };
        const atMs = 400 + events.length * 450;
        events.push({ atMs, type: 'move', target, observedTargetName: control.name });
        if (slug !== 'tooltip') events.push({ atMs: atMs + 250, type: 'click', target, observedTargetName: control.name });
      }
      if (slug === 'timeline') {
        const cards = controls.filter(c => origin === 'reference' ? c.tag === 'BUTTON' : c.role === 'button');
        const card = cards.find(c => c.x > 800) ?? cards.at(-1);
        if (card) {
          targets.card = { x: card.x + card.width / 2, y: card.y + card.height / 2 };
          events.push({ atMs: 400, type: 'move', target: 'card' }, { atMs: 800, type: 'click', target: 'card' });
        }
      }
      if (slug === 'image-viewer' && events.length) {
        events.push({ atMs: 1500, type: 'key', key: 'ArrowRight' }, { atMs: 2300, type: 'key', key: 'ArrowLeft' }, { atMs: 3100, type: 'key', key: 'Escape' });
      }
      if (slug === 'sortable-stack' && events.length) {
        events.push({ atMs: 1400, type: 'key', key: 'Space' }, { atMs: 1800, type: 'key', key: 'ArrowDown' }, { atMs: 2200, type: 'key', key: 'Escape' });
      }
      const end = Math.max(1800, ...events.map(e => e.atMs)) + 500;
      events.push({ atMs: end, type: 'move', target: 'outside' }, { atMs: end + 350, type: 'key', key: 'Escape' });
      const width = measure.reference?.stage?.width;
      const config = {
        url: origin === 'reference' ? measure.sourceUrl : `http://localhost:8102/?slug=${slug}&theme=${theme}&color=blue${width ? `&previewWidth=${width}` : ''}`,
        viewport: measure.viewport, theme, reference: origin === 'reference', backend: 'screenshots',
        loadWaitMs: origin === 'reference' ? 1800 : 5000, finalHoldMs: 500, targets, events,
        provenance: {
          phase: origin === 'reference' ? 'live reference' : 'repaired release',
          implementationHead: '8ccb169aa6d6786c451456f756af2087d2672c89',
          baseline: '5ec78ac30e1274727ddd185a883346e4d908e6c8',
          referenceRevision: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05',
          liveDeploymentRevision: 'unknown', sourceInnerWidth: width ?? null,
          buildMode: origin === 'candidate' ? 'release' : 'live deployment',
          scope: 'Default preview only. Missing targets are not exercised. Keyboard dispatch alone does not assert its outcome.',
          missingTargets,
        },
      };
      const id = `${origin}-${theme}-${slug}`;
      const configPath = join(output, 'configs', `${id}.json`);
      await writeFile(configPath, JSON.stringify(config, null, 2));
      const runDirectory = join(output, id);
      const result = await new Promise(resolve => {
        const child = spawn(process.execPath, [recorder, configPath, runDirectory], {
          env: { ...process.env, PARITY_PLAYWRIGHT: '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs' },
          stdio: ['ignore', 'pipe', 'pipe'],
        });
        let log = '';
        child.stdout.on('data', bytes => { log += bytes; });
        child.stderr.on('data', bytes => { log += bytes; });
        child.on('close', code => resolve({ code, log }));
      });
      await writeFile(join(output, `${id}.log`), result.log);
      let stats;
      try { stats = JSON.parse(await readFile(join(runDirectory, 'timeline.json'), 'utf8')).stats; } catch {}
      runs.push({ id, slug, origin, theme, code: result.code, configPath, runDirectory, missingTargets, stats });
      await writeFile(join(output, 'index.json'), JSON.stringify(runs, null, 2));
      console.log(JSON.stringify({ id, code: result.code, fps: stats?.measuredFps, missingTargets }));
    }
  }
}
