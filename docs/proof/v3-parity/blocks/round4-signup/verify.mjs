import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import assert from 'node:assert/strict';
const root=import.meta.dirname;
const manifest=JSON.parse(await readFile(join(root,'manifest.json'),'utf8'));
for(const entry of manifest.files){const bytes=await readFile(join(root,entry.path));assert.equal(bytes.length,entry.bytes,entry.path);assert.equal(createHash('sha256').update(bytes).digest('hex'),entry.sha256,entry.path);}
let sequences=0;
for(const run of ['terms-25b395e7','terms-dark-reduce-25b395e7','terms-dark-normal-25b395e7','terms-light-reduce-25b395e7']){
 const results=JSON.parse(await readFile(join(root,run,'results.json'),'utf8'));
 assert.equal(results.length,2);
 for(const r of results){assert.equal(r.pass,true,run+' '+r.id);for(const state of ['rest','invalid','name-entered','values-entered','revealed','busy','rejected','success'])assert(r.states.some(s=>s.name===state),run+' '+state);assert(r.states.find(s=>s.name==='busy').inputs.every(i=>i.disabled));if(r.id.startsWith('candidate'))assert(r.responses.some(x=>x.url.endsWith('main.dart.js')&&x.sha256==='de6dbd3e185c96d8fd220091309dba3f01d4374c07578f0793aabce9b8f8515b'));sequences++;}
}
console.log(JSON.stringify({files:manifest.files.length,sequences,pass:true}));
