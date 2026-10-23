import {build} from '/tmp/beui-sankey-runtime-20261023/node_modules/esbuild/lib/main.js';
import {mkdir, writeFile, readFile, copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {execFileSync} from 'node:child_process';
const output = resolve(process.argv[2]);
if (execFileSync('git', ['-C', '/tmp/beui-charts-reference-20261023', 'rev-parse', 'HEAD'], {encoding:'utf8'}).trim() !== 'a76e57c9bbc2837e96420b2610e9c82a3271bb05') throw Error('Wrong source pin');
await mkdir(output);
const result = await build({
  entryPoints: ['test/charts/sankey_source.tsx'], outfile: `${output}/source.js`,
  bundle: true, format: 'esm', jsx: 'automatic', metafile: true,
  alias: {'@': '/tmp/beui-charts-reference-20261023'},
  nodePaths: ['/tmp/beui-sankey-runtime-20261023/node_modules'],
  define: {'process.env.NODE_ENV': '"production"'},
});
const inputs = await Promise.all(Object.keys(result.metafile.inputs).map(async path => ({path, sha256: createHash('sha256').update(await readFile(path)).digest('hex')})));
await writeFile(`${output}/inputs.json`, JSON.stringify({pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05', inputs}, null, 2));
await copyFile('/tmp/beui-sankey-runtime-20261023/package-lock.json', `${output}/package-lock.json`);
await copyFile('example/assets/fonts/Geist-Regular.ttf', `${output}/Geist.ttf`);
await copyFile('example/assets/fonts/GeistMono-Regular.ttf', `${output}/GeistMono.ttf`);
execFileSync('/tmp/beui-sankey-runtime-20261023/node_modules/.bin/tailwindcss', ['-i','test/charts/sankey_source.css','-o',`${output}/source.css`,'--minify'], {stdio:'inherit'});
await writeFile(`${output}/index.html`, '<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="source.css"></head><body><div id="root"></div><script type="module" src="source.js"></script></body></html>', {flag:'wx'});
