import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root='docs/proof/v3-parity/charts/round4-bump';
const inputs=JSON.parse(await readFile(`${root}/build-inputs.json`));
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const file of inputs.files){const bytes=await readFile(file.path);file.sha256=hash(bytes);file.bytes=bytes.length;}
const after=inputs.builds.find(x=>x.side==='after');
after.directory='/tmp/beui-bump-r4-after-20261023-v12';
after.revision='1214692666e297c5734bfdeb13a39e8b67554c49';
const bytes=await readFile(`${after.directory}/${after.script}`);
after.sha256=hash(bytes);after.bytes=bytes.length;
inputs.buildNote='V12 compilation began with the border repair in the working tree. That exact file was committed as 12146926 during compilation. No intervening component edits occurred.';
await writeFile(`${root}/build-inputs-v12.json`,JSON.stringify(inputs,null,2),{flag:'wx'});
