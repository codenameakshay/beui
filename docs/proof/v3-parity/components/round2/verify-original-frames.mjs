import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { dirname, join, relative } from 'node:path';

const root = import.meta.dirname;
const inventoryPath = join(root, 'original-frames-archive.json');
const files = [];
const sequences = [];
const timelines = [];
async function walk(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'original-frames') sequences.push(relative(root, path));
      await walk(path);
    } else if (relative(root, path).includes('/original-frames/')) {
      assert(entry.isFile() && entry.name.endsWith('.png'), `Expected original PNG ${path}`);
      files.push(path);
    } else if (entry.name === 'timeline.json') {
      timelines.push(path);
    }
  }
}
await walk(root);
const expectedHashes = new Map();
for (const path of timelines.sort()) {
  const timeline = JSON.parse(await readFile(path));
  for (const frame of timeline.frames) {
    const file = relative(root, join(dirname(path), frame.file));
    assert(!expectedHashes.has(file), `Duplicate timeline reference ${file}`);
    expectedHashes.set(file, frame.sha256);
  }
}
const frames = [];
for (const path of files.sort()) {
  const data = await readFile(path);
  const file = relative(root, path);
  const sha256 = createHash('sha256').update(data).digest('hex');
  assert.equal(sha256, expectedHashes.get(file), `Original timeline hash ${file}`);
  frames.push({ file, bytes: data.length, sha256 });
}
assert.equal(frames.length, expectedHashes.size, 'Every timeline frame is archived');
const inventory = {
  sequences: sequences.sort(),
  totals: {
    sequences: sequences.length,
    pngFiles: frames.length,
    pngBytes: frames.reduce((sum, frame) => sum + frame.bytes, 0),
    timelines: timelines.length,
    matchedTimelineFrames: expectedHashes.size,
  },
  frames,
};
if (process.argv.includes('--write-inventory')) {
  await writeFile(inventoryPath, JSON.stringify(inventory, null, 2) + '\n');
} else {
  assert.deepEqual(inventory, JSON.parse(await readFile(inventoryPath)), 'Archive matches the committed byte inventory');
}
console.log(JSON.stringify({ ...inventory.totals, verdict: 'Every retained original PNG matches its original timeline SHA256 and archive byte inventory.' }));
