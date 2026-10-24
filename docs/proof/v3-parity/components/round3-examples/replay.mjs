import assert from 'node:assert/strict';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {spawn} from 'node:child_process';

const [input,destination,base]=process.argv.slice(2);
assert(input && destination,'Usage: node replay.mjs path/to/record-config.json new-output-directory [http://127.0.0.1:18120]');
const config=JSON.parse(await readFile(resolve(input),'utf8'));
const output=resolve(destination);
await mkdir(output);
if(base){
  const rewrite=value=>{const old=new URL(value),host=new URL(base);old.protocol=host.protocol;old.host=host.host;return old.href;};
  config.url=rewrite(config.url);config.servedJs.url=rewrite(config.servedJs.url);
}
const path=join(output,'replay-config.json');
await writeFile(path,JSON.stringify(config,null,2));
const recorder=resolve(import.meta.dirname,'../../../../../tool/parity_capture.mjs');
const code=await new Promise((resolve,reject)=>{
  const child=spawn(process.execPath,[recorder,path,join(output,'recording')],{stdio:'inherit',env:process.env});
  child.on('error',reject);child.on('exit',resolve);
});
process.exitCode=code;
