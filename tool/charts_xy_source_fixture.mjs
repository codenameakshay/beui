import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const source = process.env.BEUI_CHART_SOURCE ?? '/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/source-1ab921e6';
const revision = '1ab921e62283e788a686bc4bafa1de5ff56104ea';
const actual = execFileSync('git', ['-C', source, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
if (actual !== revision) throw new Error(`Source revision mismatch ${actual}`);
const load = file => import(pathToFileURL(`${source}/components/charts/xy/${file}.ts`));
const { normalizeXY } = await load('model');
const { niceDomain, labelStride } = await load('scale');
const { linePath, areaPath } = await load('path');
const series = [
  { id: 'a', name: 'First A', color: '#2563eb', values: [12, null, 999, -4, NaN, Infinity] },
  { id: 'a', name: 'Duplicate A', color: '#000', values: [500] },
  { id: 'b', name: 'B', color: '#0d9488', values: [7, 0, 888, 15] },
];
const categories = ['Jan', 'Feb', 'Jan', 'Mar', 'Apr', 'May', 'Jun'];
const points = [{ x: 0, y: 10 }, { x: 20, y: 0 }, { x: 40, y: 8 },
  null, { x: 60, y: 4 }, null, { x: 80, y: 5 }, { x: 100, y: 0 }];
const normalizeCases = [false, true].map(nonnegative => ({ nonnegative,
  expected: normalizeXY(series, categories, { nonnegative }) }));
const scaleCases = [
  { values: [], options: {} },
  { values: [0, 0], options: {} },
  { values: [12, 42, 27], options: {} },
  { values: [-4, 6], options: {} },
  { values: [17, 17], options: {} },
  { values: [17, 17], options: { includeZero: true } },
  { values: [12, 42], options: { fixed: [15, 35] } },
  { values: [0.0012, 0.0017], options: {} },
].map(input => ({ ...input, expected: niceDomain(input.values, input.options) }));
const pathCases = ['monotone', 'linear', 'step'].map(curve => ({ curve, points, baseline: 12,
  line: linePath(points, curve), area: areaPath(points, 12, curve) }));
const strideCases = [[1, 10], [12, 640], [12, 280], [6, 0]].map(([count, length]) => ({
  count, length, expected: labelStride(count, length) }));
const payload = {
  sourceRevision: revision,
  sourceFiles: ['model', 'scale', 'path'].map(file => ({ path: `components/charts/xy/${file}.ts`,
    sha256: createHash('sha256').update(readFileSync(`${source}/components/charts/xy/${file}.ts`)).digest('hex') })),
  normalizationInput: { series: series.map(row => ({ ...row,
    values: row.values.map(value => Number.isFinite(value) || value === null ? value : String(value)) })), categories },
  normalizeCases, scaleCases, pathCases, strideCases,
};
const rendered = `${JSON.stringify(payload, null, 2)}\n`;
const output = 'test/fixtures/charts_xy/source-contract.json';
if (process.argv.includes('--check')) {
  if (readFileSync(output, 'utf8') !== rendered) throw new Error('Source fixture differs from pinned execution');
  console.log('17 pinned-source XY cases match the frozen fixture');
} else {
  mkdirSync('test/fixtures/charts_xy', { recursive: true });
  writeFileSync(output, rendered);
  console.log(output);
}
