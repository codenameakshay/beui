import React,{useState,useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {ReturnsCalendar} from '@/components/charts/returns-calendar';
import snapshots from './snapshots.json';
function Fixture(){const [state,setState]=useState('initial');const data=snapshots[state];
useEffect(()=>{const fn=e=>{const s={i:'initial',m:'missing',r:'replace',d:'remove',e:'empty'}[e.key];if(s)setState(s)};window.addEventListener('keydown',fn);return()=>window.removeEventListener('keydown',fn)},[]);
globalThis.__fixture={state,snapshot:data,disableAnimations:matchMedia('(prefers-reduced-motion: reduce)').matches};
return <div><div>Fixture {state}</div><div>{Object.keys(snapshots).map(s=><button onClick={()=>setState(s)} style={{margin:8}}>{s}</button>)}</div><ReturnsCalendar years={data.years} returns={data.returns}/></div>};createRoot(document.getElementById('root')).render(<Fixture/>);
