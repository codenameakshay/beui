import {build} from '/tmp/beui-charts-fixture-runtime-20261023/node_modules/esbuild/lib/main.js';
import {mkdir, writeFile, readFile, copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {execFileSync} from 'node:child_process';

const output = resolve(process.argv[2]);
const directory = 'docs/proof/v3-parity/resume-20261023/multiselect-focus';
await mkdir(output,{recursive:true});
const result = await build({entryPoints:[`${directory}/source.tsx`],outfile:`${output}/source.js`,bundle:true,format:'esm',jsx:'automatic',
  alias:{'lucide-react':'/tmp/beui-multiselect-native-20261023/deps/node_modules/lucide-react/dist/esm/lucide-react.js','@':'/tmp/beui-charts-reference-20261023'},nodePaths:['/tmp/beui-charts-fixture-runtime-20261023/node_modules'],
  define:{'process.env.NODE_ENV':'"production"'},metafile:true});
const inputs = await Promise.all(Object.keys(result.metafile.inputs).map(async path => ({path,sha256:createHash('sha256').update(await readFile(path)).digest('hex')})));
await writeFile(`${output}/inputs.json`,JSON.stringify({pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',inputs},null,2));
await copyFile('/tmp/beui-charts-fixture-runtime-20261023/package-lock.json',`${output}/package-lock.json`);
execFileSync('/tmp/beui-charts-fixture-runtime-20261023/node_modules/.bin/tailwindcss',['-i',`${directory}/source.css`,'-o',`${output}/source.css`,'--minify'],{stdio:'inherit'});
for (const file of ['Geist-Regular.ttf','Geist-Medium.ttf','GeistMono-Regular.ttf','GeistMono-Medium.ttf']) await copyFile(`example/assets/fonts/${file}`,`${output}/${file}`);
await writeFile(`${output}/index.html`,'<!doctype html><html><head><meta charset="UTF-8"><link rel="stylesheet" href="source.css"></head><body><div id="root"></div><script type="module" src="source.js"></script></body></html>',{flag:'wx'});
