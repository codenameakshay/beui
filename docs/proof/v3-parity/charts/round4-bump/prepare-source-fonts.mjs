import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const directory = 'docs/proof/v3-parity/charts/round4-bump/source-fonts';
await mkdir(directory);
const manifest = [];
for (const [name,url] of [
  ['geist-live.woff2','https://beui.dev/_next/static/media/caa3a2e1cccd8315-s.p.0wgildi0cnwt9.woff2'],
  ['geist-mono-live.woff2','https://beui.dev/_next/static/media/797e433ab948586e-s.p.0r6juujl39pe6.woff2'],
]) {
  const response = await fetch(url);
  if (!response.ok) throw Error(`Font request failed ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  await writeFile(`${directory}/${name}`,bytes,{flag:'wx'});
  manifest.push({name,url,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),provenance:'Live beui.dev Latin font response. Deployment SHA unknown. Pinned layout.tsx requests Geist and Geist Mono.'});
}
await writeFile(`${directory}/manifest.json`,JSON.stringify(manifest,null,2),{flag:'wx'});
