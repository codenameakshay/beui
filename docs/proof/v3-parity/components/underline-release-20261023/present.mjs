import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const root = import.meta.dirname;
const out = join(root,process.argv[2] || 'videos-native');
await mkdir(out);
const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const page = await browser.newPage({viewport:{width:1280,height:140},deviceScaleFactor:1});
const run = args => {
  const result = spawnSync('ffmpeg',['-nostdin','-v','warning',...args],{encoding:'utf8',maxBuffer:10000000});
  if (result.status !== 0) throw new Error(result.stderr);
  return result.stderr;
};
const probe = path => {
  const result = spawnSync('ffprobe',['-v','error','-count_frames','-show_frames','-show_streams','-of','json',path],{encoding:'utf8',maxBuffer:10000000});
  if (result.status !== 0) throw new Error(result.stderr);
  return JSON.parse(result.stdout);
};
const manifest = [];
try {
  for (const theme of ['light','dark']) {
    const parts = [];
    for (const phase of ['before','after']) {
      const id = `${phase}-${theme}`;
      const input = join(root,id,'capture.mp4');
      const timeline = JSON.parse(await readFile(join(root,id,'timeline.json')));
      const caption = join(out,`${id}-caption.png`);
      const revision = phase === 'before' ? 'a4685504' : 'ce5564d2';
      await page.setContent(`<style>html,body{margin:0}#label{box-sizing:border-box;width:1280px;height:140px;background:#111;color:white;padding:12px 20px;font-family:Arial;font-size:17px;line-height:25px}</style><div id="label"><strong style="font-size:24px">Tabs underline / ${theme} / ${phase.toUpperCase()} / ${revision}</strong><br>Change. Move the 1px indicator inside the trigger's final pixel. No other production change.<br>Default, hover, pointer down/up, End, ArrowLeft, then Shift+Tab, Home, End, ArrowLeft.<br>Unmodified 592px preview wrapper. Native ${timeline.stats.measuredFps.toFixed(2)}fps average. No interpolation. Focus and pixel gaps remain.</div>`);
      await page.locator('#label').screenshot({path:caption});
      const output = join(out,`${id}-labeled.mp4`);
      const height = timeline.stats.video.height + 140;
      const log = run(['-i',input,'-i',caption,'-filter_complex',`[0:v]pad=1280:${height}:0:140:color=black[base];[base][1:v]overlay=0:0:format=auto[out]`,'-map','[out]','-an','-fps_mode','passthrough','-enc_time_base','1:1000000','-c:v','libx264','-preset','ultrafast','-crf','0','-pix_fmt','yuv444p','-video_track_timescale','1000000',output]);
      await writeFile(join(out,`${id}.log`),log);
      const original = probe(input);
      const labeled = probe(output);
      assert.equal(Number(labeled.streams[0].nb_read_frames),timeline.frames.length);
      const originalTimes = original.frames.map(f=>Number(f.best_effort_timestamp_time));
      const labeledTimes = labeled.frames.map(f=>Number(f.best_effort_timestamp_time));
      const maxPtsDeltaSeconds = Math.max(...originalTimes.map((t,i)=>Math.abs(t-labeledTimes[i])));
      assert.ok(maxPtsDeltaSeconds <= 0.000002);
      parts.push(output);
      manifest.push({id,input,output,originalFrames:timeline.frames.length,labeledFrames:Number(labeled.streams[0].nb_read_frames),maxPtsDeltaSeconds,dimensions:labeled.streams.map(s=>({width:s.width,height:s.height})),cadence:timeline.stats});
    }
    const concat = join(out,`${theme}.ffconcat`);
    await writeFile(concat,'ffconcat version 1.0\n'+parts.map(p=>`file '${p}'`).join('\n')+'\n');
    const output = join(out,`${theme}-before-after.mp4`);
    await writeFile(join(out,`${theme}-concat.log`),run(['-f','concat','-safe','0','-i',concat,'-c','copy',output]));
    const joined = probe(output);
    const expected = manifest.filter(m=>m.id.endsWith(theme)).reduce((n,m)=>n+m.originalFrames,0);
    assert.equal(Number(joined.streams[0].nb_read_frames),expected);
    manifest.push({id:`${theme}-before-after`,output,expectedFrames:expected,decodedFrames:Number(joined.streams[0].nb_read_frames),note:'Concatenated native before then after. No duplication, interpolation, scaling, or cadence normalization. PNG originals remain authoritative for exact RGB.'});
  }
  await writeFile(join(out,'manifest.json'),JSON.stringify(manifest,null,2));
} finally {await browser.close();}
