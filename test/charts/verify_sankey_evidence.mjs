import {readdir,readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root='docs/proof/v3-parity/charts/sankey';
async function census(path=''){
  const files=[];
  for(const e of await readdir(`${root}/${path}`,{withFileTypes:true})){
    const name=path?`${path}/${e.name}`:e.name;
    if(name==='README.md'||name==='EVIDENCE.json')continue;
    if(e.isDirectory())files.push(...await census(name));
    else {assert.ok(e.isFile(),`Unexpected non-file ${name}`);files.push(name);}
  }
  return files.sort();
}
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const files=await census();
if(process.argv.includes('--seal')){
  const entries=await Promise.all(files.map(async path=>{const bytes=await readFile(`${root}/${path}`);return {path,bytes:bytes.length,sha256:sha(bytes)};}));
  await writeFile(`${root}/EVIDENCE.json`,JSON.stringify({entries},null,2),{flag:'wx'});
}
const {entries}=JSON.parse(await readFile(`${root}/EVIDENCE.json`));
assert.deepEqual(files,entries.map(e=>e.path));
for(const e of entries){const bytes=await readFile(`${root}/${e.path}`);assert.equal(bytes.length,e.bytes,e.path);assert.equal(sha(bytes),e.sha256,e.path);}
const pin=JSON.parse(await readFile(`${root}/source/pin.json`));
for(const e of pin.files)assert.equal(sha(await readFile(e.archived)),e.sha256,e.path);
const recordings=await readdir(`${root}/captures`);
for(const name of recordings){
  const path=`${root}/captures/${name}`,timeline=JSON.parse(await readFile(`${path}/timeline.json`));
  const probe=JSON.parse(await readFile(`${path}/ffprobe.json`));
  const config=JSON.parse(await readFile(`${path}/config.json`));
  const scripts=JSON.parse(await readFile(`${path}/scripts.json`));
  assert.equal(scripts.find(s=>s.url===config.servedJs.url)?.sha256,config.servedJs.sha256);
  assert.equal(timeline.frames.length,Number(probe.streams[0].nb_read_frames));
  assert.deepEqual(timeline.stats.errors,[]);
  for(const f of timeline.frames)assert.equal(sha(await readFile(`${path}/${f.file}`)),f.sha256,`${name}/${f.file}`);
  for(const e of timeline.events){assert.equal(e.error,undefined);assert.ok(e.dispatchAfterMs>=e.dispatchBeforeMs);}
}
for(const [name,bundle] of [['after-release-dark-input','fixture.main.dart.js'],['after-release-light-input','fixture.main.dart.js']]){
  const config=JSON.parse(await readFile(`${root}/captures/${name}/config.json`));
  assert.equal(sha(await readFile(`${root}/builds-release/${bundle}`)),config.servedJs.sha256);
}
const provenance=JSON.parse(await readFile(`${root}/builds-release/provenance.json`));
assert.equal(sha(await readFile(`${root}/builds-release/gallery.main.dart.js`)),provenance.gallery.sha256);
for(const theme of ['dark','light']){
  const result=JSON.parse(await readFile(`${root}/gallery-release-${theme}-hashed/result.json`));
  assert.equal(result.passed,true);
  assert.equal(result.scripts.find(s=>s.url.endsWith('/after-release/main.dart.js'))?.sha256,provenance.gallery.sha256);
}
console.log(`Verified ${entries.length} evidence files and ${recordings.length} complete recordings.`);
