import React from 'react';
import {createRoot} from 'react-dom/client';
import {SankeyChartPreview} from '/tmp/beui-charts-reference-20261023/components/previews/charts/sankey-chart.preview';
import {THEMES} from '/tmp/beui-charts-reference-20261023/lib/themes';
const dark=new URLSearchParams(location.search).get('theme') !== 'light';
document.documentElement.classList.toggle('dark',dark);
for(const [name,value] of Object.entries(THEMES.default[dark?'dark':'light'])) document.documentElement.style.setProperty(name,value);
createRoot(document.getElementById('root')!).render(<SankeyChartPreview />);
