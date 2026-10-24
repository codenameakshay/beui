import {readFile,writeFile,copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';

const [outputName, build, revision, target] = process.argv.slice(2);
const root = 'docs/proof/v3-parity/charts/round4-candle-volume';
const digest = async path => createHash('sha256').update(await readFile(path)).digest('hex');
const files = execFileSync('git',['ls-files','-z','lib','example/lib','example/assets','pubspec.yaml','pubspec.lock','example/pubspec.yaml','example/pubspec.lock'],{encoding:'utf8'}).split('\0').filter(Boolean);
if (!files.includes(target)) files.push(target);
const inputs = [];
for (const file of files) inputs.push({file,sha256:await digest(file)});
await writeFile(`${root}/${outputName}`,JSON.stringify({revision,target,build:resolve(build),flutter:execFileSync('flutter',['--version'],{encoding:'utf8'}),servedJavaScriptSha256:await digest(`${build}/main.dart.js`),inputs},null,2),{flag:'wx'});
if (process.env.ROUND4_COPY_SOURCE === '1') {
  await copyFile('/tmp/beui-round4-candle-volume-source-v2-20261023/inputs.json',`${root}/source-inputs.json`);
  await copyFile('/tmp/beui-round4-candle-volume-source-v2-20261023/package-lock.json',`${root}/source-package-lock.json`);
}
