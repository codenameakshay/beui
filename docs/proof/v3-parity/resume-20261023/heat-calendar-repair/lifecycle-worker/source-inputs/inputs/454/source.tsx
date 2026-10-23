import React,{useState,useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {HeatCalendar} from '@/components/charts/heat-calendar';
import snapshots from './snapshots.json';
function Fixture(){const [state,setState]=useState('initial');const data=snapshots[state];
useEffect(()=>{const fn=e=>{const s={i:'initial',b:'blank',r:'refresh',s:'shrink',d:'date'}[e.key];if(s)setState(s)};window.addEventListener('keydown',fn);return()=>window.removeEventListener('keydown',fn)},[]);
globalThis.__fixture={state,snapshot:data,disableAnimations:matchMedia('(prefers-reduced-motion: reduce)').matches};
return <div><div>Fixture {state}</div><div>{Object.keys(snapshots).map(s=><button onClick={()=>setState(s)} style={{margin:8}}>{s}</button>)}</div><HeatCalendar weeks={data.weeks} values={data.values} maxCount={10} endDate={new Date(data.endDate+'T00:00:00Z')} color="#6366f1"/></div>};createRoot(document.getElementById('root')).render(<Fixture/>);
