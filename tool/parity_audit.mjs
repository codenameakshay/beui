import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import path from 'node:path';
import vm from 'node:vm';

const root = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
const audit = path.join(root, 'docs/proof/v3-parity/audit');
const base = 'a4d493a';
const before = '5ec78ac30e1274727ddd185a883346e4d908e6c8';
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', maxBuffer: 30e6 }).trim();
const at = (revision, file) => git('show', `${revision}:${file}`);
const hash = value => createHash('sha256').update(value).digest('hex');
const json = file => JSON.parse(readFileSync(file, 'utf8'));
const widgets = text => [...text.matchAll(/class\s+(Beui\w+)(?:<[^\n{]+>)?\s+extends\s+(?:StatelessWidget|StatefulWidget|InheritedWidget|InheritedNotifier[^\s{]*)/g)].map(m => m[1]);

function inventory(source) {
  const revision = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: source, encoding: 'utf8' }).trim();
  assert.equal(revision, 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', 'Reference revision changed. Review it before changing the audit.');
  const registryText = readFileSync(path.join(source, 'lib/registry.ts'), 'utf8');
  const registryCode = stripTypeScriptTypes(registryText.replace(/^import[^\n]+\n/, '')).replace(/\bexport /g, '');
  const registry = vm.runInNewContext(`${registryCode}\nJSON.stringify(registry)`, { agentGuides: {} }, { timeout: 1000 });
  const categories = JSON.parse(registry);
  const files = git('ls-tree', '-r', '--name-only', before, 'lib/src').split('\n').filter(f => f.endsWith('.dart'));
  const baseFiles = new Set(git('ls-tree', '-r', '--name-only', base, 'lib/src').split('\n'));
  const changed = new Set(git('diff', '--name-only', base, before, '--', 'lib/src', 'example/lib/demos').split('\n'));
  const barrel = at(before, 'lib/beui.dart');
  const publicWidgets = files.flatMap(file => {
    const text = at(before, file);
    const previous = baseFiles.has(file) ? widgets(at(base, file)) : [];
    const exportBlocks = [...barrel.matchAll(/export '([^']+)'([\s\S]*?);/g)].filter(m => `lib/${m[1]}` === file);
    return widgets(text).filter(symbol => exportBlocks.some(m => !/\bshow\b/.test(m[2]) || new RegExp(`\\b${symbol}\\b`).test(m[2]))).map(symbol => ({
      symbol, file, change: previous.includes(symbol) ? changed.has(file) ? 'changed-file' : 'unchanged' : 'added',
    }));
  });
  const catalogs = ['example/lib/explorer/catalog.dart', 'example/lib/explorer/catalog_charts.dart'].map(f => at(before, f)).join('\n');
  const rows = [...catalogs.matchAll(/ExploreEntry\(([\s\S]*?)\n  \),/g)].map(m => {
    const body = m[1];
    const slug = body.match(/slug: '([^']+)'/)[1];
    const family = body.match(/section: ExploreSection\.(\w+)/)[1];
    const sourceFamily = family === 'components' ? 'motion' : family;
    const sourceSlug = ({ 'morphing-search-chips': 'morphing-search', 'prediction-market-card': 'prediction-market' })[slug] || slug;
    const entry = categories.find(c => c.slug === sourceFamily)?.components.find(c => c.slug === sourceSlug);
    const demo = body.match(/sourceFile: '([^']+)'/)?.[1] || `example/lib/demos/${slug.replaceAll('-', '_')}_demo.dart`;
    const demoExists = git('ls-tree', '--name-only', before, demo) === demo;
    const demoText = demoExists ? at(before, demo) : '';
    const sourceFiles = entry ? [...new Set([entry.file, ...(entry.extraFiles || []), ...(entry.examples || []).map(e => e.file)])] : [];
    const stems = sourceFiles.map(f => (path.basename(f) === 'index.tsx' ? path.basename(path.dirname(f)) : path.basename(f, '.tsx')).replaceAll('-', '_'));
    stems.push(slug.replaceAll('-', '_'));
    const localFiles = files.filter(f => stems.includes(path.basename(f, '.dart')));
    if (slug === 'button') localFiles.push('lib/src/motion/button/metallic.dart');
    if (slug === 'image-viewer') localFiles.push('lib/src/motion/image_viewer.dart');
    if (slug === 'range-slider') localFiles.push('lib/src/motion/range_slider_inline.dart');
    if (family === 'charts') localFiles.push('lib/src/charts/_shared.dart');
    if (slug === 'agent-theme') localFiles.push(...files.filter(f => f.startsWith('lib/src/theme/beui_agent')));
    const matchingWidgets = publicWidgets.filter(w => localFiles.includes(w.file));
    return {
      id: `${family}/${slug}`, family, slug, galleryNewBadge: /isNew: true/.test(body),
      demo, demoExists, demoChanged: changed.has(demo), demoSha256: hash(demoText),
      sourceSlug: entry ? sourceSlug : null,
      sourceUrl: entry ? `https://beui.dev/${family === 'charts' ? 'charts' : `components/${sourceFamily}`}/${sourceSlug}` : null,
      sourceFiles: sourceFiles.map(f => ({ path: f, sha256: hash(readFileSync(path.join(source, f))) })),
      sourceExamples: (entry?.examples || []).map(e => ({ slug: e.slug, installSlug: e.installSlug || entry.slug, preview: e.previewFile })),
      sourcePreviewCandidates: entry ? [...new Set([`components/previews/${sourceFamily}/${sourceSlug}.preview.tsx`, ...(entry.examples || []).map(e => e.previewFile)])].filter(f => existsSync(path.join(source, f))) : [],
      publicWidgets: matchingWidgets,
      requiresEvidence: /isNew: true/.test(body) || changed.has(demo) || matchingWidgets.some(w => w.change !== 'unchanged'),
      verdict: 'unverified',
    };
  });
  return { schema: 1, base: git('rev-parse', base), before, reference: revision, referenceRegistrySha256: hash(registryText), rows, publicWidgets: publicWidgets.filter(w => w.change !== 'unchanged'), changedLibraryFiles: [...changed].filter(f => f.startsWith('lib/')) };
}

function validateCapture(record) {
  const problems = [];
  const need = (condition, message) => { if (!condition) problems.push(message); };
  need(['pass', 'fail', 'inconclusive', 'blocked'].includes(record.verdict), 'explicit verdict required');
  need(record.displayMatched === true && record.dataMatched === true, 'matching display and data required');
  need(typeof record.changes === 'string' && record.changes.trim().length > 0, 'text of changes required');
  need(Array.isArray(record.widgetParts) && record.widgetParts.length > 0, 'exercised widget parts required');
  for (const role of ['reference', 'before', 'after']) {
    const capture = record[role];
    need(capture?.revision && capture?.url && capture?.protocol && capture?.environment, `${role} provenance missing`);
    need(capture?.roi?.width > 0 && capture?.roi?.height > 0 && capture?.roi?.x >= 0 && capture?.roi?.y >= 0, `${role} crop missing`);
    need(capture?.fps > 0 && capture?.frames >= 2 && capture?.durationMs > 0, `${role} timing missing`);
    for (const artifact of ['video', 'still', 'framesDirectory', 'events']) {
      need(typeof capture?.[artifact] === 'string' && existsSync(path.resolve(root, capture[artifact])), `${role} ${artifact} missing`);
    }
    if (role === 'before') need(capture?.revision === before, 'before must be the task baseline');
  }
  if (record.state === 'rest') need(record.restGeometryReviewed === true, 'settled geometry review required');
  else if (record.state === 'reduced-motion') need(record.reducedMotion?.noIntermediateMovement === true && record.reducedMotion?.targetReached === true && record.reducedMotion?.opacityPolicyMatched === true && record.reducedMotion?.rawMeasurements, 'reduced-motion geometry, final target and opacity measurements required');
  else need(record.motion?.motion_status === 'compared' && Number.isFinite(record.motion?.motion_score), 'motion static or inconclusive is not pass');
  need(record.static?.reviewed === true && record.static?.rawResult, 'static crop diff and review required');
  need(record.temporalReviewed === true, 'motion trajectory, text, and exit review required');
  return problems;
}

function check() {
  const inv = json(path.join(audit, 'inventory.json'));
  const matrix = json(path.join(audit, 'states.json'));
  const evidence = json(path.join(audit, 'evidence.json'));
  const problems = [];
  let obligations = 0;
  for (const row of inv.rows) {
    const states = matrix[row.slug];
    if (!states) problems.push(`${row.id}: state matrix missing`);
    if (!row.requiresEvidence) continue;
    const examples = row.sourceExamples.map(e => `example/${e.installSlug}/${e.slug}`);
    for (const state of ['rest', 'hover-exit', 'keyboard', 'reduced-motion', ...(states || []), ...examples]) {
      obligations++;
      const capture = evidence.captures.find(c => c.id === row.id && c.state === state);
      if (!capture) { problems.push(`${row.id}/${state}: reference, before, after and comparison absent`); continue; }
      const errors = validateCapture(capture);
      if (capture.verdict !== 'pass') errors.push(`verdict ${capture.verdict}`);
      problems.push(...errors.map(e => `${row.id}/${state}: ${e}`));
    }
  }
  const unassigned = inv.publicWidgets.filter(w => w.change !== 'unchanged' && !inv.rows.some(r => r.publicWidgets.some(p => p.symbol === w.symbol)));
  for (const w of unassigned) problems.push(`${w.symbol}: changed public widget has no owning route`);
  for (const w of inv.publicWidgets.filter(w => w.change !== 'unchanged')) {
    if (!evidence.captures.some(c => c.verdict === 'pass' && validateCapture(c).length === 0 && c.widgetParts.includes(w.symbol))) problems.push(`${w.symbol}: no passing composition capture`);
  }
  console.log(JSON.stringify({ verdict: problems.length ? 'NOT_CERTIFIED' : 'complete-index-requires-independent-review', galleryRows: inv.rows.length, requiredRoutes: inv.rows.filter(r => r.requiresEvidence).length, stateObligations: obligations, indexedCaptures: evidence.captures.length, problems }, null, 2));
  process.exitCode = problems.length ? 1 : 0;
}

const [command, source] = process.argv.slice(2);
if (command === 'inventory') console.log(JSON.stringify(inventory(path.resolve(source)), null, 2));
else if (command === 'assets') {
  const assets = git('ls-tree', '-r', '-l', before, '--', 'docs/proof', '.github/screenshots', 'example/proof').split('\n').map(line => {
    const [, blob, bytes, file] = line.match(/^\d+ blob (\w+)\s+(\d+)\t(.+)$/);
    return { file, baselineBlob: blob, bytes: Number(bytes) };
  });
  console.log(JSON.stringify({ before, assets }, null, 2));
}
else if (command === 'reference') {
  const results = [];
  for (const slug of ['tooltip', 'treemap', 'voice-orb', 'card-folder']) {
    const url = `https://beui.dev/r/${slug}.json`;
    const response = await fetch(url);
    assert.equal(response.status, 200);
    const entry = await response.json();
    results.push({ url, files: entry.files.filter(f => f.path.startsWith('components/')).map(f => {
      const local = readFileSync(path.join(source, f.path), 'utf8');
      return { path: f.path, sourceSha256: hash(local), liveSha256: hash(f.content), matchesAfterRemovingAttributionComment: local === f.content.replace(/^\/\/ beui\.dev\/[^\n]*\n/m, '') };
    }) });
  }
  console.log(JSON.stringify({ normalization: 'Remove one injected // beui.dev/... attribution line only.', results }, null, 2));
}
else if (command === 'check') check();
else if (command === 'self-test') {
  assert.deepEqual(widgets('class BeuiPart extends StatelessWidget {} class BeuiData {}'), ['BeuiPart']);
  for (const status of ['static', 'capture_unreliable', 'compared']) {
    assert(validateCapture({ verdict: 'pass', motion: { motion_status: status, motion_score: null } }).includes('motion static or inconclusive is not pass'));
  }
  assert(validateCapture({ verdict: 'pass' }).includes('matching display and data required'));
  console.log('PASS: empty proof, missing provenance, static motion, unreliable capture and null scores rejected');
} else throw new Error('Usage: node tool/parity_audit.mjs inventory SOURCE | reference SOURCE | assets | check | self-test');
