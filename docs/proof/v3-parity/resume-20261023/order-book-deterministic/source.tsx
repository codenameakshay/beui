import React, {useState,useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {useReducedMotion} from 'motion/react';
import {OrderBook, OrderBookHeader, OrderBookSide, OrderBookSpread, OrderBookDepthSummary, OrderBookBalance} from '/tmp/beui-charts-reference-20261023/components/charts/order-book';
import snapshots from './snapshots.json';
function Fixture() {
 const [state,setState] = useState('initial');
 const [selections,setSelections] = useState<any[]>([]);
 const [changes,setChanges] = useState<any[]>([]);
 const reduce=useReducedMotion();
 useEffect(()=>{ const fn=(e:KeyboardEvent)=>{const s=({r:'reorder',e:'empty',b:'bids',a:'asks',i:'initial',s:'step'} as any)[e.key];if(s)setState(s)};window.addEventListener('keydown',fn);return()=>window.removeEventListener('keydown',fn)},[]);
 const data=(snapshots as any)[state];
 (globalThis as any).__fixture={state,paused:true,disableAnimations:!!reduce,snapshot:data,selections,changes};
 return <main style={{width:560}}><p style={{textAlign:'center'}}>Paused fixture · {state}</p><div style={{display:'flex',justifyContent:'center'}}>{Object.keys(snapshots).map(label=><button style={{padding:'12px'}} key={label} onClick={()=>setState(label)}>{label}</button>)}</div>
 <OrderBook {...data} baseSymbol="BTC" quoteSymbol="USD" onActiveLevelChange={v=>setChanges(p=>[...p,v])} onLevelSelect={(v,side)=>setSelections(p=>[...p,{side,...v}])}>
 <OrderBookHeader/><OrderBookSide side="ask"/><OrderBookSpread/><OrderBookSide side="bid"/><OrderBookDepthSummary/><OrderBookBalance/>
 </OrderBook></main>
}
createRoot(document.getElementById('root')!).render(<Fixture/>);
