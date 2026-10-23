import { mkdir, readFile, readdir, copyFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';

const output = path.join(import.meta.dirname, 'logs');
await mkdir(output);
const manifest = [];
for (const file of (await readdir('/tmp')).filter(f => f.startsWith('beui-blocks-r2-') && /\.(log|json)$/.test(f)).sort()) {
  const source = path.join('/tmp', file);
  const destination = file.replace('beui-blocks-r2-', '');
  await copyFile(source, path.join(output, destination));
  const bytes = await readFile(source);
  manifest.push({ source, destination, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') });
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`${manifest.length} raw command logs copied without edits`);
