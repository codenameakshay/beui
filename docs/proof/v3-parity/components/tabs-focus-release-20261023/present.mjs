import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const root=import.meta.dirname;
const out=join(root,process.argv[2] || 'videos-native');
await mkdir(out);
const run=(cmd,args)=>{
  const r=spawnSync(cmd,args,{encoding:'utf8',maxBuffer:10000000});
  if(r.status!==0) throw new Error(r.stderr);
  return r.stdout;
};
const probe=path=>JSON.parse(run('ffprobe',['-v','error','-count_frames','-show_frames','-show_streams','-of','json',path]));
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const page=await browser.newPage({viewport:{width:1280,height:140},deviceScaleFactor:1});
const manifest=[];
try {
  for(const motion of ['no-preference','reduce']) for(const theme of ['light','dark']) {
    const parts=[];
    let total=0;
    for(const phase of ['before','after']) {
      const id=`${phase}-${theme}-${motion}`;
      const input=join(root,id,'capture.mp4');
      const timeline=JSON.parse(await readFile(join(root,id,'timeline.json')));
      const revision=phase==='before'?'ce5564d2':'bd6df418';
      const caption=join(out,`${id}-caption.png`);
      await page.setContent(`<style>html,body{margin:0}#label{box-sizing:border-box;width:1280px;height:140px;background:#111;color:white;padding:12px 20px;font-family:Arial;font-size:17px;line-height:25px}</style><div id="label"><strong style="font-size:24px">Tabs native focus / ${theme} / ${motion} / ${phase.toUpperCase()} / ${revision}</strong><br>Change. Pointer activation owns keyboard focus. Keyboard outline no longer fills the trigger.<br>Native Open hover, down, up, pointer exit, End, ArrowLeft. Semantics off throughout recording.<br>Unmodified 592px preview wrapper. Native ${timeline.stats.measuredFps.toFixed(2)}fps average. No interpolation. Not exact parity proof.</div>`);
      await page.locator('#label').screenshot({path:caption});
      const output=join(out,`${id}-labeled.mp4`);
      run('ffmpeg',['-nostdin','-v','error','-i',input,'-i',caption,'-filter_complex',`[0:v]pad=1280:${timeline.stats.video.height+140}:0:140:color=black[b];[b][1:v]overlay=0:0:format=auto[out]`,'-map','[out]','-an','-fps_mode','passthrough','-enc_time_base','1:1000000','-c:v','libx264','-preset','ultrafast','-crf','0','-pix_fmt','yuv444p','-video_track_timescale','1000000',output]);
      const original=probe(input),labeled=probe(output);
      assert.equal(Number(labeled.streams[0].nb_read_frames),timeline.frames.length);
      const delta=Math.max(...original.frames.map((f,i)=>Math.abs(Number(f.best_effort_timestamp_time)-Number(labeled.frames[i].best_effort_timestamp_time))));
      assert.ok(delta<=0.000002);
      total+=timeline.frames.length;
      parts.push(output);
      manifest.push({id,originalFrames:timeline.frames.length,labeledFrames:Number(labeled.streams[0].nb_read_frames),maxPtsDeltaSeconds:delta,dimensions:{width:1280,height:timeline.stats.video.height+140},cadence:timeline.stats});
    }
    const concat=join(out,`${theme}-${motion}.ffconcat`);
    await writeFile(concat,'ffconcat version 1.0\n'+parts.map(p=>`file '${p}'`).join('\n')+'\n');
    const output=join(out,`${theme}-${motion}-before-after.mp4`);
    run('ffmpeg',['-nostdin','-v','error','-f','concat','-safe','0','-i',concat,'-c','copy',output]);
    const joined=probe(output);
    assert.equal(Number(joined.streams[0].nb_read_frames),total);
    manifest.push({id:`${theme}-${motion}-before-after`,expectedFrames:total,decodedFrames:Number(joined.streams[0].nb_read_frames),note:'Native before then after. No interpolation, scaling, duplicate frames, or cadence normalization. Original PNGs are authoritative for exact RGB.'});
  }
  await writeFile(join(out,'manifest.json'),JSON.stringify(manifest,null,2));
} finally {await browser.close();}
