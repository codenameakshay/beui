import {readFile,writeFile} from 'node:fs/promises';
const [metricsDirectory, candlePhase = 'after-v6', volumePhase = 'after-v11', output = 'comparison.html'] = process.argv.slice(2);
const root = 'docs/proof/v3-parity/charts/round4-candle-volume';
const metrics = JSON.parse(await readFile(`${root}/${metricsDirectory}/metrics.json`,'utf8'));
const number = value => value.toLocaleString('en-US');
const rows = metrics.rows.filter(row=>row.region==='chart');
const sections = [];
for (const chart of ['volume','candle']) {
  const phase = chart==='volume'?volumePhase:candlePhase;
  for (const state of ['pointer-a','rest','home']) {
    const preference = 'dark-no-preference';
    const before = rows.find(row=>row.chart===chart&&row.state===state&&row.preference===preference&&row.phase==='before-v2');
    const after = rows.find(row=>row.chart===chart&&row.state===state&&row.preference===preference&&row.phase===phase);
    if(!before||!after)throw Error(`Missing comparison ${chart} ${state}`);
    const slug = `${chart}-${preference}-${state}`;
    const figures = [
      ['Before',`${metricsDirectory}/${slug}-before-v2-chart-candidate.png`,`${number(before.differentPixels)} differing pixels`],
      ['Pinned source',`${metricsDirectory}/${slug}-${phase}-chart-source.png`,'a76e57c9, not the unknown live deployment'],
      ['After',`${metricsDirectory}/${slug}-${phase}-chart-candidate.png`,`${number(after.differentPixels)} differing pixels. FAIL, not exact parity.`],
      ['Absolute RGB difference',`${metricsDirectory}/${slug}-${phase}-chart-absolute-diff.png`,'No scaling, alignment, recoloring, or excluded pixels in the comparison.'],
    ];
    sections.push(`<details ${chart==='volume'&&state==='pointer-a'?'open':''}><summary>${chart==='volume'?'Volume profile':'Candle'} · ${state} · dark / motion enabled</summary><div class="figures">${figures.map(([label,path,caption])=>`<figure><figcaption><strong>${label}</strong><br>${caption}</figcaption><img src="${path}" alt="${label}, ${chart}, ${state}"></figure>`).join('')}</div></details>`);
  }
}
const rest = rows.filter(row=>row.state==='rest'&&row.phase!=='before-v2');
const html = `<!doctype html><html><head><meta charset="utf-8"><title>Candle and volume native comparison</title><style>body{font:14px/1.5 system-ui;color:var(--foreground,#eee);margin:0}h1{font-size:20px}h2{font-size:16px}p{max-width:70ch}table{border-collapse:collapse;margin:16px 0;width:100%;text-align:left}td,th{padding:6px;border-bottom:1px solid #6666}details{margin:16px 0}summary{cursor:pointer;font-weight:600}figure{margin:16px 0;max-width:584px}figcaption{margin-bottom:8px}img{display:block;width:100%;height:auto;background:#151515}.figures{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,584px),584px));gap:16px}</style></head><body><h1>Native source comparison remains nonzero</h1><p>Owned source differences are implemented. These native crops retain the remaining pixel failures. The source is pinned. Live beui.dev has an unknown deployment SHA.</p><table><thead><tr><th>Chart / preference</th><th>Remaining pixels</th><th>Exact verdict</th></tr></thead><tbody>${rest.map(row=>`<tr><td>${row.chart} / ${row.preference}</td><td>${number(row.differentPixels)} / ${number(row.pixels)}</td><td>FAIL</td></tr>`).join('')}</tbody></table><p>The links and README retain all 14 states in both preferences, full native PNGs, MP4s, event timelines, served JavaScript hashes, and effective motion probes. Display resizing here does not change those originals.</p>${sections.join('')}</body></html>`;
await writeFile(`${root}/${output}`,html,{flag:'wx'});
