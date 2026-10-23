import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const root = import.meta.dirname;
const selections = [];
for (const batch of ['press-before', 'press-after', 'press-reduced']) {
  const preferences = batch === 'press-reduced' ? ['reduce'] : ['no-preference'];
  const themes = batch === 'press-reduced' ? ['dark'] : ['dark', 'light'];
  for (const preference of preferences) {
    for (const theme of themes) {
      for (const kind of ['reference', 'candidate']) {
        const directory = `${batch}/${kind}-${theme}-${preference}`;
        const timeline = JSON.parse(await readFile(path.join(root, directory, 'timeline.json'), 'utf8'));
        for (const [state, atMs] of [['held', 2100], ['released-open', 3100], ['keyboard-closed', 4100]]) {
          const frame = timeline.frames.find(f => f.requestedMs >= timeline.stats.sequenceStartMs + atMs);
          if (!frame) throw new Error(`No actual sample ${directory} ${state}`);
          selections.push({ directory, state, original: `${directory}/${frame.file}`, sha256: frame.sha256,
            requestRelativeMs: frame.requestedMs - timeline.stats.sequenceStartMs,
            responseRelativeMs: frame.receivedMs - timeline.stats.sequenceStartMs,
            note: 'Untouched actual sample. Manual observations are separate. No exposure timestamp or interpolated movement.' });
        }
      }
    }
  }
}
await writeFile(path.join(root, 'press-frame-review.json'), JSON.stringify(selections, null, 2));
console.log(JSON.stringify(selections.filter(s => s.state === 'held'), null, 2));
