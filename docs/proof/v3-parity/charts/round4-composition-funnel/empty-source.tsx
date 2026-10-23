import React from 'react';
import {createRoot} from 'react-dom/client';
import {CompositionChart} from '/tmp/beui-charts-reference-20261023/components/charts/composition-chart';
import {FunnelChart} from '/tmp/beui-charts-reference-20261023/components/charts/funnel-chart';
import {THEMES} from '/tmp/beui-charts-reference-20261023/lib/themes';

document.documentElement.classList.add('dark');
for (const [key,value] of Object.entries(THEMES.default.dark)) document.documentElement.style.setProperty(key,value);
const dataCase = new URLSearchParams(location.search).get('case');
createRoot(document.getElementById('root')!).render(<main style={{width:752}}>{dataCase === 'composition' ? <CompositionChart series={[]} periods={[]}/> : <FunnelChart stages={dataCase === 'invalid' ? [{id:'invalid',label:'Invalid',value:-1}] : []}/>}</main>);
