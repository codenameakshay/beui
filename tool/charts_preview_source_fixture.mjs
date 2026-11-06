import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';

const source = process.env.BEUI_CHART_SOURCE ?? '/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/source-1ab921e6';
const revision = '1ab921e62283e788a686bc4bafa1de5ff56104ea';
const expectedSourceHashes = new Map([
  ['line-chart.preview.tsx', '70c9ff8e2f6c94d15f18f2c7bd477330887a2115918a176b6760c70321e739d1'],
  ['line-chart.usage.tsx', '82f37cd7484688155a0b2f7003400878444a4f8f833a4f604b39bcd1526852d6'],
  ['bar-chart.preview.tsx', 'afabc917359385073beb6945d66540d27bed695594f6462e181b0483317bdd04'],
  ['bar-chart.usage.tsx', 'a4ba758ff3bc75cb2d5f3eb3e4acefb1f249cfb42966c6c1123cd13abb303ef9'],
  ['sparkline.preview.tsx', '1e7f7d967c1a729761a74c52564d85ceb990197703d234c4d4517022c7c211dd'],
  ['sparkline.usage.tsx', '37cfba510af826918f113847d8514a8f6b7bd4c637bccaa8afe6feb450872777'],
]);
const actualRevision = execFileSync('git', ['-C', source, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
if (actualRevision !== revision) throw new Error(`Source revision mismatch ${actualRevision}`);

const previewRoot = `${source}/components/previews/charts`;
const sourceFiles = [
  'line-chart.preview.tsx', 'line-chart.usage.tsx',
  'bar-chart.preview.tsx', 'bar-chart.usage.tsx',
  'sparkline.preview.tsx', 'sparkline.usage.tsx',
].map(name => {
  const path = `${previewRoot}/${name}`;
  const bytes = readFileSync(path);
  const sha256 = hash(bytes);
  if (sha256 !== expectedSourceHashes.get(name)) throw new Error(`${name}: source SHA256 mismatch ${sha256}`);
  return {
    path: `components/previews/charts/${name}`,
    sha256,
    text: bytes.toString('utf8'),
  };
});
const sources = new Map(sourceFiles.map(file => [file.path.split('/').at(-1), file]));
const extractions = [];

function hash(value) {
  return createHash('sha256').update(value).digest('hex');
}

function extract(fileName, symbol, expression) {
  const sourceFile = sources.get(fileName);
  const matcher = new RegExp(expression.source, expression.flags.includes('g') ? expression.flags : `${expression.flags}g`);
  const matches = [...sourceFile.text.matchAll(matcher)];
  if (matches.length !== 1) throw new Error(`${fileName}: expected one bounded ${symbol} match, found ${matches.length}`);
  return recordExtraction(sourceFile, symbol, matches[0]);
}

function extractAll(fileName, symbol, expression, expectedCount) {
  const sourceFile = sources.get(fileName);
  const matcher = new RegExp(expression.source, expression.flags.includes('g') ? expression.flags : `${expression.flags}g`);
  const matches = [...sourceFile.text.matchAll(matcher)];
  if (matches.length !== expectedCount) throw new Error(`${fileName}: expected ${expectedCount} bounded ${symbol} matches, found ${matches.length}`);
  return matches.map(match => recordExtraction(sourceFile, symbol, match));
}

function recordExtraction(sourceFile, symbol, match) {
  const raw = match[0];
  const start = match.index;
  const startLine = sourceFile.text.slice(0, start).split('\n').length;
  const endLine = startLine + raw.split('\n').length - 1;
  extractions.push({ path: sourceFile.path, symbol, startLine, endLine, sha256: hash(raw) });
  return raw;
}

function runDeclaration(name, declaration, context = Object.create(null)) {
  const javascript = stripTypeScriptTypes(declaration, { mode: 'strip' });
  return vm.runInNewContext(`${javascript}\n${name}`, context, { timeout: 1000 });
}

function readConstant(file, name, expression) {
  return runDeclaration(name, extract(file, name, expression));
}

const months = readConstant('line-chart.preview.tsx', 'months', /const months = \[[^\n]+\];/);
const lineMakeSeriesSource = extract(
  'line-chart.preview.tsx', 'makeSeries', /function makeSeries\(seed: number\): LineChartSeries\[\] \{[\s\S]*?\n\}/,
);
const lineMakeSeries = runDeclaration('makeSeries', lineMakeSeriesSource, { months });
const regions = readConstant('bar-chart.preview.tsx', 'regions', /const regions = \[[^\n]+\];/);
const barMakeSeriesSource = extract(
  'bar-chart.preview.tsx', 'makeSeries', /function makeSeries\(seed: number\): BarChartSeries\[\] \{[\s\S]*?\n\}/,
);
const barMakeSeries = runDeclaration('makeSeries', barMakeSeriesSource, { regions });
const sparklineWalkSource = extract(
  'sparkline.preview.tsx', 'walk', /function walk\(seed: number, length: number, start: number, drift: number, noise: number\) \{[\s\S]*?\n\}/,
);
const sparklineWalk = runDeclaration('walk', sparklineWalkSource);
const days = readConstant('sparkline.preview.tsx', 'days', /const days = Array\.from\(\{ length: 60 \}, \(_, i\) =>[\s\S]*?\n\);/);

function sourceNumber(fileName, symbol, expression) {
  const matched = extract(fileName, symbol, expression);
  const value = Number(matched.match(/-?\d+(?:\.\d+)?/)[0]);
  if (!Number.isFinite(value)) throw new Error(`${fileName}: ${symbol} is not finite`);
  return value;
}

function sourceString(fileName, symbol, expression) {
  const matched = extract(fileName, symbol, expression);
  const value = matched.match(expression)?.[1];
  if (value === undefined) throw new Error(`${fileName}: ${symbol} did not capture a string`);
  return value;
}

function sourceNumberFrom(text, expression, description) {
  const value = Number(text.match(expression)?.[1]);
  if (!Number.isFinite(value)) throw new Error(`Could not read ${description} from pinned source`);
  return value;
}

function seedMetadata(fileName, initialSeed, delay = null) {
  const initial = sourceNumber(fileName, 'initialSeed', new RegExp(`useState\\(${initialSeed}\\)`));
  const transitionCount = fileName === 'line-chart.preview.tsx' ? 2 : 1;
  const transitionSources = extractAll(fileName, 'seedTransition', /setSeed\(\(value\) => \(value \* 48271\) % 2147483647\)/, transitionCount);
  const transitionSource = transitionSources[0];
  const multiplier = Number(transitionSource.match(/\* (\d+)/)[1]);
  const modulus = Number(transitionSource.match(/% (\d+)/)[1]);
  const transition = transitionSource.slice('setSeed('.length, -1);
  const next = vm.runInNewContext(`(${transition})(${initial})`, Object.create(null), { timeout: 1000 });
  const seed = { initial, multiplier, modulus, next, transitionCount };
  if (delay !== null) {
    seed.reloadDelayMs = sourceNumber(fileName, 'reloadDelayMs', /\}, (\d+)\);/);
  }
  return seed;
}

const lineSeed = seedMetadata('line-chart.preview.tsx', 7, true);
const lineVariant = sourceString('line-chart.preview.tsx', 'initialVariant', /useState<"line" \| "area">\("([^"]+)"\)/);
const lineSeries = [lineSeed.initial, lineSeed.next].map(seed => ({ seed, series: lineMakeSeries(seed) }));
const line = {
  seed: lineSeed,
  categories: months,
  initialVariant: lineVariant,
  variants: ['line', 'area'],
  loading: { startsOn: 'Reload', finishesAfterMs: lineSeed.reloadDelayMs, states: ['ready', 'loading'] },
  generator: {
    minimumValue: sourceNumberFrom(lineMakeSeriesSource, /Math\.max\((\d+(?:\.\d+)?), value \+ drift/, 'line minimum'),
  },
  snapshots: lineSeries,
  colors: lineSeries[0].series.map(({ id, color }) => ({ id, color })),
};

const barSeed = seedMetadata('bar-chart.preview.tsx', 11);
const barLayout = sourceString('bar-chart.preview.tsx', 'initialLayout', /useState<"grouped" \| "stacked">\("([^"]+)"\)/);
const barOrientation = sourceString('bar-chart.preview.tsx', 'initialOrientation', /useState<"vertical" \| "horizontal">\("([^"]+)"\)/);
const barSorted = sourceString('bar-chart.preview.tsx', 'initialSorted', /useState\((false|true)\)/) === 'true';
const barSortSource = extract('bar-chart.preview.tsx', 'sortProp', /sort=\{sorted \? "([^"]+)" : "([^"]+)"\}/);
const barScale = barMakeSeriesSource.match(/const scale = \[([^\]]+)\]/)[1].split(',').map(Number);
const barSeries = [barSeed.initial, barSeed.next].map(seed => ({ seed, series: barMakeSeries(seed) }));
const bar = {
  seed: barSeed,
  categories: regions,
  initialLayout: barLayout,
  layouts: ['grouped', 'stacked'],
  initialOrientation: barOrientation,
  orientations: ['vertical', 'horizontal'],
  initialSorted: barSorted,
  sortToggle: { stateProp: 'sort', sorted: barSortSource.match(/sorted \? "([^"]+)"/)[1], unsorted: barSortSource.match(/: "([^"]+)"/)[1], changesGeneratedSeries: false },
  generator: {
    scale: barScale,
    randomOffset: sourceNumberFrom(barMakeSeriesSource, /\* \((\d+(?:\.\d+)?) \+ random\(\)\)/, 'bar random offset'),
  },
  snapshots: barSeries,
  colors: barSeries[0].series.map(({ id, color }) => ({ id, color })),
};

const windowSize = sourceNumber('sparkline.preview.tsx', 'windowSize', /const WINDOW = (\d+);/);
const walkCalls = ['revenue', 'users', 'errors'].map(name => {
  const call = extract('sparkline.preview.tsx', `${name}Walk`, new RegExp(`const ${name} = walk\\(([^)]+)\\);`));
  const [seed, length, start, drift, noise] = call.match(/walk\(([^)]+)\)/)[1].split(',').map(Number);
  if (length !== 60) throw new Error(`${name}: expected the pinned 60-sample source walk, found ${length}`);
  return { name, seed, length, start, drift, noise };
});
const cardsSource = extract('sparkline.preview.tsx', 'cards', /const cards = \[[\s\S]*?\n  \];/);
const cards = cardsSource.split(/(?=id: ")/).slice(1).map(block => ({
  id: block.match(/id: "([^"]+)"/)[1],
  title: block.match(/title: "([^"]+)"/)[1],
  color: block.match(/color: "([^"]+)"/)[1],
  invertDelta: /invertDelta: true/.test(block),
}));
if (cards.length !== walkCalls.length) throw new Error(`Expected ${walkCalls.length} sparkline cards, found ${cards.length}`);
const sparklineParameters = walkCalls.map(({ name, ...walkArgs }, index) => ({
  ...cards[index], ...walkArgs,
  values: sparklineWalk(walkArgs.seed, walkArgs.length, walkArgs.start, walkArgs.drift, walkArgs.noise),
}));
const finalOffset = days.length - windowSize;
const offsetTransition = extract('sparkline.preview.tsx', 'offsetTransition', /setOffset\(\(value\) => Math\.min\(days\.length - WINDOW, value \+ (\d+)\)\)/);
const offsetIncrement = Number(offsetTransition.match(/value \+ (\d+)/)[1]);
const disabledAtMax = extract('sparkline.preview.tsx', 'disabledAtMaxOffset', /disabled=\{offset >= days\.length - WINDOW\}/);
const interactiveSource = extract('sparkline.preview.tsx', 'interactiveSparkline', /<Sparkline\n          data=\{slice\(users\)\}[\s\S]*?\n        \/>/);
const interactiveColor = interactiveSource.match(/color="([^"]+)"/)[1];
const interactiveHeight = Number(interactiveSource.match(/height=\{(\d+)\}/)[1]);
const interactiveStrokeWidth = Number(interactiveSource.match(/strokeWidth=\{(\d+)\}/)[1]);
const interactiveLabel = interactiveSource.match(/label="([^"]+)"/)[1];
const initialOffset = sourceNumber('sparkline.preview.tsx', 'initialOffset', /useState\((\d+)\)/);
const offsets = [initialOffset, Math.min(finalOffset, initialOffset + offsetIncrement), finalOffset];
const sparkline = {
  windowSize,
  generator: {
    minimumValue: sourceNumberFrom(sparklineWalkSource, /Math\.max\((\d+(?:\.\d+)?), value \+ drift/, 'sparkline minimum'),
  },
  offsets: offsets.map(offset => ({
    offset,
    labels: days.slice(offset, offset + windowSize),
    series: sparklineParameters.map(({ id, title, color, invertDelta, values }) => ({
      id, title, color, invertDelta, values: values.slice(offset, offset + windowSize),
    })),
  })),
  interactive: {
    id: sparklineParameters[1].id, color: interactiveColor, height: interactiveHeight, strokeWidth: interactiveStrokeWidth,
    data: sparklineParameters[1].values.slice(0, windowSize),
    labels: days.slice(0, windowSize),
    label: interactiveLabel,
  },
  maxOffset: finalOffset,
  addSample: { increment: offsetIncrement, clampsAt: finalOffset, disabledAtMaxOffset: Boolean(disabledAtMax) },
};

const payload = {
  sourceRevision: revision,
  sourceFiles: sourceFiles.map(({ path, sha256 }) => ({ path, sha256 })),
  extractions,
  line,
  bar,
  sparkline,
};
const rendered = `${JSON.stringify(payload, null, 2)}\n`;
const output = 'test/fixtures/charts_xy/preview-contract.json';
const check = process.argv.includes('--check');
if (check) {
  if (readFileSync(output, 'utf8') !== rendered) throw new Error('Preview fixture differs from pinned source execution');
  console.log(`Pinned preview contract matches: ${lineSeries.length} line seeds, ${barSeries.length} bar seeds, ${sparkline.offsets.length} sparkline windows (${sparkline.offsets.reduce((n, item) => n + item.series.length, 0)} windowed series)`);
} else {
  mkdirSync('test/fixtures/charts_xy', { recursive: true });
  writeFileSync(output, rendered);
  console.log(`${output}: ${lineSeries.length} line seeds, ${barSeries.length} bar seeds, ${sparkline.offsets.length} sparkline windows (${sparkline.offsets.reduce((n, item) => n + item.series.length, 0)} windowed series)`);
}
