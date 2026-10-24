import React, {useState,useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {SankeyChart} from '/tmp/beui-charts-reference-20261023/components/charts/sankey-chart';
function App(){
 const [includeB,setB]=useState(true);
 useEffect(()=>{const h=(e:KeyboardEvent)=>{if(e.key==='r')setB(false);if(e.key==='i')setB(true)};window.addEventListener('keydown',h);return()=>window.removeEventListener('keydown',h)},[]);
 return <main style={{width:300,margin:'0 auto'}}><button style={{height:48}} onClick={()=>{}}>Before</button>{new URLSearchParams(location.search).get('scenario')==='offscreen'&&<div style={{height:800}}/>}<SankeyChart nodes={[{id:'a',label:'A'},{id:'b',label:'B'},{id:'c',label:'C'}]} links={[{source:'a',target:'c',value:30},...(includeB?[{source:'b',target:'c',value:70}]:[])]}/><button style={{height:48}} onClick={()=>{}}>Outside</button></main>
}
createRoot(document.getElementById('root')!).render(<App/>);
