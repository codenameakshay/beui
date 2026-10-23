import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readdir,readFile,writeFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {spawnSync} from 'node:child_process';
const root='docs/proof/v3-parity/charts/round4-bump';
const seal='ARCHIVE.json';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
async function walk(directory,prefix=''){
  const result=[];
  for(const entry of await readdir(directory,{withFileTypes:true})){
    const name=join(prefix,entry.name);
    if(entry.isDirectory())result.push(...await walk(join(directory,entry.name),name));
    else if(name!==seal)result.push(name);
  }
  return result.sort();
}
const files=await Promise.all((await walk(root)).map(async path=>{const bytes=await readFile(join(root,path));return {path,bytes:bytes.length,sha256:hash(bytes)};}));
const byPath=new Map(files.map(file=>[file.path,file]));
let frames=0,timelines=0;
const recordings=[];
for(const file of files.filter(x=>x.path.endsWith('/timeline.json'))){
  const directory=dirname(file.path);
  const timeline=JSON.parse(await readFile(join(root,file.path)));
  for(const frame of timeline.frames){assert.equal(byPath.get(join(directory,frame.file))?.sha256,frame.sha256,join(directory,frame.file));frames++;}
  const probe=spawnSync('ffprobe',['-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames,width,height','-of','json',join(root,directory,'capture.mp4')],{encoding:'utf8'});
  assert.equal(probe.status,0,probe.stderr);
  const stream=JSON.parse(probe.stdout).streams[0];
  assert.equal(Number(stream.nb_read_frames),timeline.frames.length,directory);
  const config=JSON.parse(await readFile(join(root,directory,'config.json')));
  const scripts=JSON.parse(await readFile(join(root,directory,'scripts.json')));
  assert(scripts.some(x=>x.url===config.servedJs.url&&x.sha256===config.servedJs.sha256),directory);
  const environment=JSON.parse(await readFile(join(root,directory,'environment.json')));
  assert.equal(environment.reducedMotion,config.reducedMotion==='reduce',directory);
  if(config.requireFlutterProbe){
    assert.equal(environment.flutterCapture.disableAnimations,config.reducedMotion==='reduce',directory);
    assert.equal(environment.flutterCapture.platformDisableAnimations,config.reducedMotion==='reduce',directory);
    assert.equal(environment.flutterCapture.motionOverride,null,directory);
  }
  recordings.push({directory,frames:timeline.frames.length,fps:timeline.stats.measuredFps,maxIntervalMs:timeline.stats.maxIntervalMs,stream,servedJs:config.servedJs});
  timelines++;
}
assert.equal(timelines,files.filter(x=>x.path.endsWith('/capture.mp4')).length);
const archive={version:1,implementation:'1214692666e297c5734bfdeb13a39e8b67554c49',pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',counts:{files:files.length,bytes:files.reduce((sum,x)=>sum+x.bytes,0),pngs:files.filter(x=>x.path.endsWith('.png')).length,timelines,frames},recordings,files};
if(process.argv.includes('--seal'))await writeFile(join(root,seal),JSON.stringify(archive,null,2),{flag:'wx'});
else assert.deepEqual(archive,JSON.parse(await readFile(join(root,seal))));
console.log(JSON.stringify({verified:true,counts:archive.counts,recordings:recordings.map(x=>({directory:x.directory,frames:x.frames,fps:x.fps,maxIntervalMs:x.maxIntervalMs}))},null,2));
