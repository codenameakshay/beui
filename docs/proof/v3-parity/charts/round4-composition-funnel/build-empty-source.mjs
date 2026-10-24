import {build} from '/tmp/beui-charts-fixture-runtime-20261023/node_modules/esbuild/lib/main.js';
import {mkdir, writeFile, readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const output = `${root}/empty-source-build`;
await mkdir(output);
const result = await build({entryPoints:[`${root}/empty-source.tsx`],outfile:`${output}/empty.js`,bundle:true,format:'esm',jsx:'automatic',alias:{'@':'/tmp/beui-charts-reference-20261023'},nodePaths:['/tmp/beui-charts-fixture-runtime-20261023/node_modules'],define:{'process.env.NODE_ENV':'"production"'},metafile:true});
const inputs = await Promise.all(Object.keys(result.metafile.inputs).map(async path => ({path,sha256:createHash('sha256').update(await readFile(path)).digest('hex')})));
await writeFile(`${output}/inputs.json`,JSON.stringify({pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',inputs},null,2),{flag:'wx'});
await writeFile(`${output}/index.html`,'<!doctype html><html><head><meta charset="UTF-8"><link rel="stylesheet" href="/source/source.css"></head><body><div id="root"></div><script type="module" src="empty.js"></script></body></html>',{flag:'wx'});
