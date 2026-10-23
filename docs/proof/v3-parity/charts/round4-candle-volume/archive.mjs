import {readFile,writeFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join,relative,resolve} from 'node:path';
import assert from 'node:assert/strict';

const root = resolve('docs/proof/v3-parity/charts/round4-candle-volume');
const [mode, name = 'archive-v1.json'] = process.argv.slice(2);
const digest = async path => createHash('sha256').update(await readFile(path)).digest('hex');
const walk = async directory => (await Promise.all((await readdir(directory,{withFileTypes:true})).map(async entry => entry.isDirectory() ? walk(join(directory,entry.name)) : [join(directory,entry.name)]))).flat();
const time = ms => {
  const value = Math.max(0,Math.round(ms));
  return `${String(Math.floor(value/3600000)).padStart(2,'0')}:${String(Math.floor(value/60000)%60).padStart(2,'0')}:${String(Math.floor(value/1000)%60).padStart(2,'0')},${String(value%1000).padStart(3,'0')}`;
};
if (mode === 'seal') {
  for (const path of (await walk(root)).filter(p=>p.endsWith('/timeline.json'))) {
    const timeline = JSON.parse(await readFile(path,'utf8'));
    if (!timeline.frames.length) throw Error(`Empty capture ${path}`);
    const base = timeline.frames[0].metadata.timestamp*1000-timeline.stats.originEpochMs;
    const events = timeline.events;
    const captions = events.map((event,index) => `${index+1}\n${time(event.dispatchBeforeMs-base)} --> ${time(index+1<events.length?events[index+1].dispatchBeforeMs-base:timeline.stats.durationMs)}\n${event.caption}\n`).join('\n');
    await writeFile(path.replace('timeline.json','captions.srt'),captions,{flag:'wx'}).catch(error=>{if(error.code!=='EEXIST')throw error;});
  }
  const files = (await walk(root)).filter(p=>/\.(png|mp4|webm|srt)$/.test(p)||/(timeline|config|environment|scripts|observations|states|inputs|package-lock)\.json$/.test(p)).sort();
  const entries = [];
  for (const path of files) entries.push({file:relative(root,path),sha256:await digest(path)});
  await writeFile(join(root,name),JSON.stringify({algorithm:'sha256',files:entries},null,2),{flag:'wx'});
  console.log(`Sealed ${entries.length} original and derived artifacts in ${name}`);
} else if(mode === 'verify') {
  const manifest = JSON.parse(await readFile(join(root,name),'utf8'));
  for (const entry of manifest.files) assert.equal(await digest(join(root,entry.file)),entry.sha256,entry.file);
  let frames = 0;
  let recordings = 0;
  const cadence = [];
  for (const path of (await walk(root)).filter(p=>p.endsWith('/timeline.json'))) {
    const timeline = JSON.parse(await readFile(path,'utf8'));
    const directory = path.slice(0,-'/timeline.json'.length);
    assert.equal(timeline.stats.errors.length,0,path);
    assert.equal(timeline.stats.video.decodedFrames,timeline.frames.length,path);
    for (const frame of timeline.frames) assert.equal(await digest(join(directory,frame.file)),frame.sha256,frame.file);
    const environment = JSON.parse(await readFile(join(directory,'environment.json'),'utf8'));
    const config = JSON.parse(await readFile(join(directory,'config.json'),'utf8'));
    assert.equal(environment.reducedMotion,config.reducedMotion==='reduce',path);
    if(config.requireFlutterProbe) assert.equal(environment.flutterCapture.disableAnimations,environment.reducedMotion,path);
    if(config.servedJs) {
      const scripts = JSON.parse(await readFile(join(directory,'scripts.json'),'utf8'));
      assert(scripts.some(script=>script.url===config.servedJs.url&&script.sha256===config.servedJs.sha256),path);
    }
    frames += timeline.frames.length;
    recordings++;
    cadence.push({directory:relative(root,directory),fps:timeline.stats.measuredFps,maxGapMs:timeline.stats.maxIntervalMs,verdict:timeline.stats.fastMotionVerdict});
  }
  console.log(JSON.stringify({verifiedFiles:manifest.files.length,recordings,originalFrames:frames,cadence},null,2));
} else throw Error('Use seal or verify');
