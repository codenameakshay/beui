import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const root = import.meta.dirname;
const cases = [
  ['flows-normal/candidate-card-folder-dark-no-preference', 'revealed', 1200],
  ['flows-normal/candidate-card-folder-dark-no-preference', 'masked', 2100],
  ['flows-normal/candidate-card-folder-dark-no-preference', 'opened', 3000],
  ['flows-normal/candidate-card-folder-dark-no-preference', 'keyboard-closed', 3900],
  ['after-final-card/candidate-card-folder-dark', 'shared-tooltip-hover', 950],
  ['flows-final-feedback/candidate-feedback-widget-dark-no-preference', 'rejected', 4800],
  ['flows-final-feedback/candidate-feedback-widget-dark-no-preference', 'success', 6900],
  ['flows-normal/candidate-morphing-search-chips-dark-no-preference', 'chip-added', 3000],
  ['after-secondary/candidate-prediction-market-card-dark', 'failed-rates-SVG-sizing', 1200],
  ['after-svg-final/candidate-prediction-market-card-dark', 'rates-SVG-slot-filled', 1200],
  ['after-secondary/candidate-number-dark', 'secondary-numbers', 2200],
  ['after-secondary/candidate-text-animation-dark', 'secondary-text-examples', 2200],
];
const results = [];
for (const [directory, state, atMs] of cases) {
  const timeline = JSON.parse(await readFile(path.join(root, directory, 'timeline.json'), 'utf8'));
  const target = timeline.stats.sequenceStartMs + atMs;
  const frame = timeline.frames.find(f => f.requestedMs >= target);
  if (!frame) throw new Error(`No frame after ${directory} ${atMs}`);
  results.push({ directory, state, targetRelativeMs: atMs, original: `${directory}/${frame.file}`, requestRelativeMs: frame.requestedMs - timeline.stats.sequenceStartMs, responseRelativeMs: frame.receivedMs - timeline.stats.sequenceStartMs, sha256: frame.sha256, note: 'Selected untouched original. Exposure is unknown within its request-response interval. Selection alone is not state verification.' });
}
await writeFile(path.join(root, process.argv[2] || 'frame-review-final.json'), JSON.stringify(results, null, 2));
console.log(JSON.stringify(results.map(({ state, original }) => ({ state, original })), null, 2));
