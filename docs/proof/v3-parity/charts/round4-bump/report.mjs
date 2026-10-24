import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const root='docs/proof/v3-parity/charts/round4-bump';
const read=async path=>JSON.parse(await readFile(`${root}/${path}`));
const inputs=await read('build-inputs-v12.json');
const candidate=inputs.builds.find(x=>x.side==='after');
const source=inputs.builds.find(x=>x.side==='source');
const checks=[];
for(const [kind,before,after,count]of[
  ['keyboard and trusted touch','interactions-source-v3/states.json','interactions-after-v12b/states.json',38],
  ['mouse and keyboard handoff','mouse-source-v1/states.json','mouse-after-v12/states.json',16],
  ['narrow keyboard and touch pan','narrow-source-v1/states.json','narrow-after-v12/states.json',4],
]){
  const a=await read(before),b=await read(after);
  assert.equal(a.length,count);assert.equal(b.length,count);
  checks.push({kind,source:before,candidate:after,sourceStates:a.length,candidateStates:b.length});
}
const observations=await read('static-after-v12/observations.json');
assert.equal(observations.length,12);
for(const x of observations){
  assert.equal(x.errors.length,0);
  assert(x.scripts.some(s=>s.url.endsWith('/main.dart.js')&&s.sha256===candidate.sha256));
  assert.equal(x.environment.flutterCapture.disableAnimations,true);
  assert.equal(x.environment.flutterCapture.platformDisableAnimations,true);
  assert.equal(x.environment.flutterCapture.motionOverride,null);
}
const recordings=[];
for(const side of ['source','after'])for(const motion of ['no-preference','reduce'])for(const touch of [false,true]){
  const name=`${side}-${motion}${touch?'-touch':''}-${side==='source'?'v3':'v12'}`;
  const directory=`captures/${name}`;
  const timeline=await read(`${directory}/timeline.json`);
  const environment=await read(`${directory}/environment.json`);
  const scripts=await read(`${directory}/scripts.json`);
  const expected=side==='after'?candidate:source;
  assert(scripts.some(x=>x.sha256===expected.sha256));
  assert.equal(environment.reducedMotion,motion==='reduce');
  if(side==='after'){
    assert.equal(environment.flutterCapture.disableAnimations,motion==='reduce');
    assert.equal(environment.flutterCapture.platformDisableAnimations,motion==='reduce');
    assert.equal(environment.flutterCapture.motionOverride,null);
  }
  if(touch){
    const reports=await read(`${directory}/observed-touch.json`);
    assert(reports.some(x=>x.events.filter(e=>e.type==='pointerdown').length===3));
    assert(reports.every(x=>x.maxTouchPoints===1&&x.hoverCapable===false&&x.events.every(e=>e.isTrusted)));
  }
  recordings.push({directory,frames:timeline.frames.length,stats:timeline.stats,servedJs:expected.sha256});
}
const staticDiff=await read('diff-after-v12/metrics.json');
const interactionDiff=await read('diff-interactions-v12b/metrics.json');
const baselineDiff=await read('diff-before-v1/metrics.json');
const border=await read('source-border-metrics-v2.json');
assert.equal(border.length,3);assert(border.every(x=>x.border==='1px'));
const summary={implementation:candidate.revision,candidateJs:candidate.sha256,pinnedSource:inputs.pinnedSource,liveDeployment:'unknown',checks,staticDiff,interactionDiff,baselineDiff,recordings,sourceComputedBorders:border,unresolved:[
  'Every static and interaction comparison has nonzero exact RGBA differences.',
  'Flutter button selection exposes aria-current, not the source aria-pressed.',
  'Rapid unpaced 28-Tab burst lost focus in interactions-after-v12. Paced 60ms source and candidate checks do not waive it.',
  'Shared Tooltip surface, arrow, collision and warm-delay behavior remain parent-owned.',
  'Native recording cadence cannot certify short-spring trajectories.',
  'The unchanged bump widget golden still fails.',
]};
await writeFile(`${root}/measurements.json`,JSON.stringify(summary,null,2),{flag:'wx'});
const css=`body{font:14px/1.5 system-ui;color:var(--foreground,#ddd);margin:0}h1,h2,h3{line-height:1.2}h1{font-size:22px}h2{font-size:18px;margin-top:28px}p{max-width:90ch}a{color:var(--primary,#8bbcff)}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}figure{margin:0}img,video{display:block;width:100%;height:auto;border-radius:6px}figcaption{margin:6px 0 14px}.fail{color:var(--warning,#ffbd60)}table{border-collapse:collapse;width:100%}td,th{text-align:left;padding:8px;border-bottom:1px solid var(--border,#444)}code{overflow-wrap:anywhere}summary{cursor:pointer;margin:12px 0}small{color:var(--muted-foreground,#aaa)}`;
const image=(path,label)=>`<figure><a href="${path}"><img src="${path}" alt="${label}"></a><figcaption>${label}</figcaption></figure>`;
const table=`<table><thead><tr><th>Native static PNG</th><th>Exact different pixels</th><th>Plot region</th><th>Legend region</th></tr></thead><tbody>${staticDiff.results.map(x=>`<tr><td>${x.name}</td><td>${x.exactMismatchedPixels.toLocaleString('en-US')}</td><td>${x.regions.plot}</td><td>${x.regions.legend}</td></tr>`).join('')}</tbody></table>`;
const video=(side,motion,touch)=>{
  const directory=`captures/${side}-${motion}${touch?'-touch':''}-${side==='source'?'v3':'v12'}`;
  return `<figure><video controls preload="metadata" src="${directory}/capture.mp4"><track kind="captions" src="${directory}/captions.srt" label="Recorded actions"></video><figcaption>${side==='source'?'Pinned source':'Final Flutter'} · ${motion} · ${touch?'trusted touch':'native mouse and keyboard'}. <a href="${directory}/timeline.json">Actual timeline</a></figcaption></figure>`;
};
const html=`<!doctype html><html><head><meta charset="utf-8"><title>Bump round-four proof</title><style>${css}</style></head><body>
<h1>Bump chart round-four proof</h1>
<p>The source rank/change grid and native button behavior are implemented. Exact visual parity still fails. Source deployment SHA is unknown. These are pinned-source consumer fixtures, not a live deployment comparison.</p>
<p><code>${candidate.revision}</code><br>Served JavaScript SHA-256 <code>${candidate.sha256}</code></p>
<h2>Before, source, and final after</h2><p>Wide PNGs remain native 800 × 600 files. Narrow PNGs remain 390 × 600. Click an image to inspect its original pixels. Display sizing does not change the files.</p>
<div class="grid">${image('static-before-v1/dark-default.png','Before · a2942181 · dark default')}${image('static-source-v1/dark-default.png','Pinned source · a76e57c9 · dark default')}${image('static-after-v12/dark-default.png','Final after · 12146926 · dark default')}${image('diff-after-v12/dark-default.png','Absolute RGB difference · no resize or registration')}</div>
<p class="fail">Dark default has 9,706 different pixels, compared with 12,559 before. The legend has 1,800, compared with 3,099 before. The pass threshold is zero.</p>
<h2>Every static example</h2>${table}
${['dark','light'].flatMap(theme=>['composed','narrow','empty','missing','update'].map(variant=>`<details><summary>${theme} · ${variant} · source and final after</summary><div class="grid">${image(`static-source-v1/${theme}-${variant}.png`,`${theme} ${variant} · pinned source`)}${image(`static-after-v12/${theme}-${variant}.png`,`${theme} ${variant} · final after`)}${image(`diff-after-v12/${theme}-${variant}.png`,`${theme} ${variant} · exact raw difference`)}</div></details>`)).join('')}
<h2>Native input and motion footage</h2><p>Source and candidate each pass 38 paced keyboard/touch states, 16 mouse/handoff states, and four narrow checks. These results retain the distinct ARIA attributes. An earlier unpaced Tab-burst failure remains unresolved.</p>
${['no-preference','reduce'].map(motion=>[false,true].map(touch=>`<div class="grid">${video('source',motion,touch)}${video('after',motion,touch)}</div>`).join('')).join('')}
<h2>Residual gates</h2><ul>${summary.unresolved.map(x=>`<li>${x}</li>`).join('')}</ul>
<p>Default source height is 349.703125px and candidate height is 349.7142857142857px. Narrow, empty, and missing heights agree. Visible text and curve raster differences remain. Their causes are not all assigned to shared rendering.</p>
<p><a href="README.md">Full source mapping, commands, rejected runs, and owned commits</a> · <a href="measurements.json">Machine-readable measurements</a> · <a href="ARCHIVE.json">Final byte seal</a></p>
</body></html>`;
await writeFile(`${root}/proof.html`,html,{flag:'wx'});
const inline=`<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body><p>Bump chart · dark default · native PNG proof</p><div class="grid">${image('static-before-v1/dark-default.png','Before · a2942181')}${image('static-source-v1/dark-default.png','Pinned source · a76e57c9')}${image('static-after-v12/dark-default.png','Final after · 12146926')}</div><p class="fail">12,559 → 9,706 different pixels. Legend 3,099 → 1,800. Exact parity still fails.</p><p>Source and candidate each pass 86 native input states at the recorded cadence. Rapid Tab-burst focus loss, ARIA metadata, the unchanged golden, and motion certification remain separate unresolved gates.</p></body></html>`;
await writeFile(`${root}/inline-proof.html`,inline,{flag:'wx'});
console.log(JSON.stringify({verified:true,checks,staticPixels:staticDiff.results.map(x=>({name:x.name,pixels:x.exactMismatchedPixels})),recordings:recordings.map(x=>({directory:x.directory,frames:x.frames,fps:x.stats.measuredFps}))},null,2));
