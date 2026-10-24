import {readdir, readFile, writeFile} from 'node:fs/promises';
import {join, dirname} from 'node:path';
import {createHash} from 'node:crypto';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const selected = process.argv.slice(2);
const directories = selected.length ? selected.map(name => join(root, name)) : [root];
async function timelines(directory) {
  const found = [];
  for (const entry of await readdir(directory, {withFileTypes: true})) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) found.push(...await timelines(path));
    else if (entry.name === 'timeline.json') found.push(path);
  }
  return found;
}
function stamp(milliseconds) {
  const value = Math.max(0, Math.round(milliseconds));
  const h = Math.floor(value / 3600000);
  const m = Math.floor(value / 60000) % 60;
  const s = Math.floor(value / 1000) % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')},${String(value % 1000).padStart(3, '0')}`;
}
const manifest = [];
for (const path of (await Promise.all(directories.map(timelines))).flat()) {
  const bytes = await readFile(path);
  const timeline = JSON.parse(bytes);
  const origin = timeline.frames[0].requestedMs ?? timeline.stats.startMs;
  const events = timeline.events.filter(event => event.caption);
  const text = events.map((event, index) => {
    const start = event.dispatchAfterMs - origin;
    const end = (events[index + 1]?.dispatchBeforeMs ?? timeline.stats.stopMs) - origin;
    return `${index + 1}\n${stamp(start)} --> ${stamp(Math.max(start + 1, end))}\n${event.caption}\n`;
  }).join('\n');
  const output = join(dirname(path), 'captions.srt');
  await writeFile(output, text, {flag: 'wx'});
  manifest.push({timeline: path, timelineSha256: createHash('sha256').update(bytes).digest('hex'), output, timing: 'Actual dispatch-after to next dispatch-before, relative to first screenshot request. Screenshot exposure remains inside its request-response interval.', captions: events.length});
}
await writeFile(`${root}/${process.env.CAPTION_MANIFEST ?? (selected.length ? 'caption-provenance-v4.json' : 'caption-provenance.json')}`, JSON.stringify(manifest, null, 2), {flag: 'wx'});
console.log(`Appended captions for ${manifest.length} original recordings without changing PNGs, videos, or timelines.`);
