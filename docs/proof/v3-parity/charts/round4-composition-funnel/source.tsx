import React, {useState} from 'react';
import {createRoot} from 'react-dom/client';
import {CompositionChartPreview} from '/tmp/beui-charts-reference-20261023/components/previews/charts/composition-chart.preview';
import {FunnelChart} from '/tmp/beui-charts-reference-20261023/components/charts/funnel-chart';
import {THEMES} from '/tmp/beui-charts-reference-20261023/lib/themes';

const params = new URLSearchParams(location.search);
document.documentElement.classList.toggle('dark', params.get('theme') !== 'light');
for (const [key,value] of Object.entries(THEMES.default[params.get('theme') === 'light' ? 'light' : 'dark'])) document.documentElement.style.setProperty(key,value);
const labels = ['Visitors', 'Signed up', 'Activated', 'Started trial', 'Subscribed'];
const cohorts = [[24000,15600,10800,7200,4320],[28000,18200,13650,9100,6370],[22000,13200,7920,4752,2376]];
function Funnel() {
  const [cohort, setCohort] = useState(0);
  const [direction, setDirection] = useState<'vertical'|'horizontal'>('vertical');
  return <div className="space-y-6">
    <div className="flex flex-wrap items-center justify-between gap-4">
      <div><h3 className="text-sm font-medium">From first visit to first payment</h3><p className="mt-1 text-xs text-muted-foreground">Product conversion · Sample cohorts</p></div>
      <button onClick={() => setCohort((cohort+1)%3)}>Next cohort</button>
    </div>
    <fieldset aria-label="Funnel direction" className="inline-flex gap-1 rounded-full bg-muted/50 p-1">
      {(['vertical','horizontal'] as const).map(value => <button key={value} aria-pressed={direction===value} onClick={() => setDirection(value)} className="px-3 py-1 text-xs">{value==='vertical'?'Vertical':'Horizontal'}</button>)}
    </fieldset>
    <FunnelChart direction={direction} stages={labels.map((label,i)=>({id:label,label,value:cohorts[cohort][i]}))}/>
    <p className="text-center text-[11px] text-muted-foreground">Inspect a stage to see conversion and drop-off</p>
  </div>;
}
createRoot(document.getElementById('root')!).render(<main style={{width:Math.min(Number(params.get('width')||752),innerWidth-96)}}>{params.get('slug')==='composition-chart'?<CompositionChartPreview/>:<Funnel/>}</main>);
