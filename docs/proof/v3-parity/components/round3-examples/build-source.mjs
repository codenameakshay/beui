import assert from 'node:assert/strict';
import {mkdir, readFile, writeFile, copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve, join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';

const source = resolve(process.env.BEUI_SOURCE ?? '/tmp/beui-v3-parity-components-source');
const runtime = resolve(process.env.BEUI_BUILD_RUNTIME ?? '/tmp/beui-charts-fixture-runtime-20261023');
const output = resolve(process.argv[2]);
const revision = execFileSync('git', ['-C', source, 'rev-parse', 'HEAD'], {encoding:'utf8'}).trim();
assert.equal(revision, 'a76e57c9bbc2837e96420b2610e9c82a3271bb05');
await mkdir(output);
const {build} = await import(pathToFileURL(join(runtime, 'node_modules/esbuild/lib/main.js')));
const result = await build({entryPoints:[join(import.meta.dirname, 'source.tsx')], outfile:join(output, 'source.js'), bundle:true, format:'esm', jsx:'automatic', alias:{'@':source}, nodePaths:[join(source,'node_modules')], define:{'process.env.NODE_ENV':'"production"'}, metafile:true});
const inputs = await Promise.all(Object.keys(result.metafile.inputs).map(async path => ({path, sha256:createHash('sha256').update(await readFile(path)).digest('hex')})));
await writeFile(join(output,'inputs.json'), JSON.stringify({revision, inputs},null,2));
await copyFile(join(source,'bun.lock'), join(output,'source-bun.lock'));
const globals = await readFile(join(source,'app/globals.css'),'utf8');
await writeFile(join(output,'globals.css'), globals.replace('"tailwindcss"',JSON.stringify(join(runtime,'node_modules/tailwindcss'))));
const faces = [[400,'Regular'],[500,'Medium'],[600,'SemiBold'],[700,'Bold']];
for (const [weight,name] of faces) await copyFile(join(source,`node_modules/geist/dist/fonts/geist-sans/Geist-${name}.woff2`),join(output,`geist-${weight}.woff2`));
await writeFile(join(output,'input.css'), `@import '${join(output,'globals.css')}';
@source '${join(source,'components')}';
${faces.map(([weight]) => `@font-face {font-family:Geist;src:url('geist-${weight}.woff2');font-weight:${weight};}`).join('\n')}
:root {--font-geist-sans:Geist;--font-sans:Geist;}
body {margin:0;background:var(--background);color:var(--foreground);font-family:Geist;}
#stage {width:592px;min-height:360px;display:flex;align-items:center;justify-content:center;margin:0 auto;}
`);
execFileSync(join(runtime,'node_modules/.bin/tailwindcss'), ['-i',join(output,'input.css'),'-o',join(output,'source.css'),'--minify'],{stdio:'inherit'});
await writeFile(join(output,'index.html'),'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="source.css"></head><body><div id="root"></div><script type="module" src="source.js"></script></body></html>');
