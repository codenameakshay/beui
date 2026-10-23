import assert from 'node:assert/strict';
import {readFile,readdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
const root=import.meta.dirname;
const hash=b=>createHash('sha256').update(b).digest('hex');
async function walk(dir,prefix='') {const out=[];for(const e of await readdir(dir,{withFileTypes:true})){const p=join(prefix,e.name);if(e.isDirectory())out.push(...await walk(join(dir,e.name),p));else if(p!=='MANIFEST.json')out.push(p);}return out.sort();}
const files=await walk(root), entries=[];
for(const path of files){const b=await readFile(join(root,path));entries.push({path,bytes:b.length,sha256:hash(b)});}
if(process.argv.includes('--seal'))await writeFile(join(root,'MANIFEST.json'),JSON.stringify(entries,null,2),{flag:'wx'});
assert.deepEqual(entries,JSON.parse(await readFile(join(root,'MANIFEST.json'))));
let sequences=0,frames=0;
for(const folder of ['final-light-c66a8825','final-dark-c66a8825','final-light-reduce-c66a8825','final-dark-reduce-c66a8825']){
 const results=JSON.parse(await readFile(join(root,folder,'results.json')));
 for(const r of results){assert.equal(r.pass,true);assert.equal(r.states.length,9);if(r.id.startsWith('candidate')){assert.equal(r.probe.disableAnimations,r.motion==='reduce');assert(r.responses.some(x=>x.sha256==='55ed90091a0f2213adc12a478b6013faa43cbf88aa60cfe38c4126dd84e19bcb'));}sequences++;}
}
for(const folder of await readdir(join(root,'captures'))){
 const dir=join(root,'captures',folder),t=JSON.parse(await readFile(join(dir,'timeline.json'))),c=JSON.parse(await readFile(join(dir,'config.json'))),e=JSON.parse(await readFile(join(dir,'environment.json')));
 assert.deepEqual(t.stats.errors,[]);assert.equal(e.reducedMotion,c.reducedMotion==='reduce');
 if(c.requireFlutterProbe){assert.equal(e.flutterCapture.disableAnimations,e.reducedMotion);const scripts=JSON.parse(await readFile(join(dir,'scripts.json')));assert(scripts.some(x=>x.url===c.servedJs.url&&x.sha256===c.servedJs.sha256));}
 for(const f of t.frames){assert.equal(hash(await readFile(join(dir,f.file))),f.sha256);frames++;}
 const p=spawnSync('ffprobe',['-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','json',join(dir,'capture.mp4')],{encoding:'utf8'});assert.equal(p.status,0);assert.equal(Number(JSON.parse(p.stdout).streams[0].nb_read_frames),t.frames.length);
}
console.log(JSON.stringify({files:entries.length,sequences,frames,recordings:4}));
