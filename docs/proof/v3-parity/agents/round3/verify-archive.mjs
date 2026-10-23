import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, relative } from 'node:path';

const root = resolve('docs/proof/v3-parity/agents/round3');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
async function files(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = `${directory}/${entry.name}`;
    if (entry.isDirectory()) result.push(...await files(path));
    else result.push(path);
  }
  return result.sort();
}
if (process.argv[2] === 'create') {
  const entries = [];
  for (const path of await files(root)) {
    if (path.endsWith('/archive-sha256.json')) continue;
    const bytes = await readFile(path);
    entries.push({ path: relative(root, path), bytes: bytes.length, sha256: digest(bytes) });
  }
  await writeFile(`${root}/archive-sha256.json`, JSON.stringify(entries, null, 2), { flag: 'wx' });
  console.log(JSON.stringify({ files: entries.length, bytes: entries.reduce((n, e) => n + e.bytes, 0) }));
} else {
  const entries = JSON.parse(await readFile(`${root}/archive-sha256.json`));
  for (const entry of entries) {
    const bytes = await readFile(resolve(root, entry.path));
    assert.equal(bytes.length, entry.bytes, entry.path);
    assert.equal(digest(bytes), entry.sha256, entry.path);
  }
  console.log(JSON.stringify({ verified: entries.length, originalPngs: entries.filter(e => e.path.endsWith('.png')).length, originalVideos: entries.filter(e => /\.(mp4|webm)$/.test(e.path)).length }));
}
