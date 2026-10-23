import React, {useState, useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {BumpChart, BumpChartPlot, BumpChartLegend} from '/tmp/beui-charts-reference-20261023/components/charts/bump-chart';

const ranks = [[4,3,2,3,2,1],[1,1,3,2,1,2],[3,2,1,1,3,3],[2,4,5,4,5,4],[5,5,4,5,4,5]];
const names = ['Studio','Canvas','Layers','Orbit','Frame'];
const colors = ['#8b5cf6','#0d9488','#f59e0b','#3b82f6','#f43f5e'];
const params = new URLSearchParams(location.search);
document.documentElement.classList.toggle('dark', params.get('theme') !== 'light');
function Fixture() {
  const [updated, update] = useState(false);
  const variant = params.get('variant') ?? 'default';
  useEffect(() => {
    const listener = (event: KeyboardEvent) => {if (event.key.toLowerCase() === 'u') update(value => !value);};
    document.addEventListener('keydown', listener);
    return () => document.removeEventListener('keydown', listener);
  }, []);
  const series = variant === 'empty' ? [] : names.map((name, i) => ({id:name.toLowerCase(), name, color:colors[i], ranks:variant === 'missing' ? [] : updated ? [...ranks[i]].reverse() : ranks[i]}));
  return <main style={{width:variant === 'narrow' ? 320 : 592, margin:'80px auto 0'}}>
    <BumpChart label="Product rankings" periods={['Apr','May','Jun','Jul','Aug','Sep']} series={series}>
      {variant === 'composed' ? <><BumpChartPlot/><BumpChartLegend/></> : undefined}
    </BumpChart>
  </main>;
}
createRoot(document.getElementById('root')!).render(<Fixture/>);
