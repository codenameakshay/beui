import React, {useEffect, useState} from 'react';
import {createRoot} from 'react-dom/client';
import {StatusBar} from '/tmp/beui-charts-reference-20261023/components/charts/status-bar';

const periods = [
  {id: 'a', label: 'Monday', status: 'operational', description: 'Monday detail'},
  {id: 'b', label: 'Tuesday', status: 'degraded', description: 'Tuesday detail'},
  {id: 'c', label: 'Wednesday', status: 'operational', description: 'Wednesday detail'},
];

function Fixture() {
  const [included, setIncluded] = useState(true);
  useEffect(() => {
    const update = (event: KeyboardEvent) => {
      if (event.key.toLowerCase() === 'r') setIncluded(false);
      if (event.key.toLowerCase() === 'i') setIncluded(true);
    };
    window.addEventListener('keydown', update);
    return () => window.removeEventListener('keydown', update);
  }, []);
  return <main style={{width: 480}}>
    <p>Status identity ownership fixture</p>
    <p>Tab focuses Tuesday. R removes it. I reinserts it.</p>
    <p>Focus stays on the native inspector throughout.</p>
    <div style={{height: 120}} />
    <StatusBar data={included ? periods : [periods[0], periods[2]]} defaultActiveId="b" />
    <p style={{marginTop: 24}}>Visible periods: {included ? 'a b c' : 'a c'}</p>
  </main>;
}

document.documentElement.classList.toggle('dark', new URLSearchParams(location.search).get('theme') !== 'light');
createRoot(document.getElementById('root')!).render(<Fixture />);
