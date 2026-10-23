import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const root = join(import.meta.dirname, '..');
const originalCheckout = process.argv[2] ?? process.cwd();
const results = [];
for (const [name, expected] of [['before-sha256.json', 300], ['release-video-sha256.json', 74]]) {
  const inventory = JSON.parse(await readFile(join(root, name)));
  const records = Array.isArray(inventory) ? inventory : inventory.records;
  assert.equal(records.length, expected);
  for (const record of records) {
    const path = record.path.startsWith('docs/')
      ? record.path
      : join('docs/proof/v3-parity/components', record.path);
    const bytes = await readFile(join(originalCheckout, path));
    assert.equal(bytes.length, record.bytes, record.path);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), record.sha256, record.path);
  }
  results.push({ inventory: name, originalCheckout, records: records.length, verdict: 'all original bytes and hashes preserved' });
}
await writeFile(join(import.meta.dirname, 'original-integrity.json'), JSON.stringify(results, null, 2));
console.log(JSON.stringify(results));
