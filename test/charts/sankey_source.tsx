import React from 'react';
import {createRoot} from 'react-dom/client';
import {SankeyChartPreview} from '/tmp/beui-charts-reference-20261023/components/previews/charts/sankey-chart.preview';
document.documentElement.classList.toggle('dark', new URLSearchParams(location.search).get('theme') !== 'light');
createRoot(document.getElementById('root')!).render(<SankeyChartPreview />);
