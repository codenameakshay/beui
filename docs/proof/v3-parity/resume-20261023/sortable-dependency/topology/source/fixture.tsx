import React,{useState} from 'react';
import {createRoot} from 'react-dom/client';
import {SortableList} from './components/motion/sortable-list';
const initial=[{id:'A'},{id:'B'},{id:'C'}];
function Fixture(){
 const mode=new URLSearchParams(location.search).get('mode')||'reject';
 const [items,setItems]=useState(initial),[calls,setCalls]=useState<string[][]>([]),[disabled,setDisabled]=useState(mode==='disabled');
 (globalThis as any).__fixture={mode,calls,ownerOrder:items.map(x=>x.id),disabled,reduce:matchMedia('(prefers-reduced-motion: reduce)').matches};
 return <main onKeyDown={e=>{if(e.key==='r')setItems(initial);if(e.key==='m')setItems([{id:'B'},{id:'A'},{id:'D'}]);if(e.key==='i')setItems([{id:'B'},{id:'A'},{id:'C'}]);if(e.key==='d')setDisabled(true)}}><h1>Sortable Undo fixture</h1><SortableList defaultItems={initial} items={mode==='uncontrolled'?undefined:items} disabled={disabled} getItemLabel={x=>x.id} onItemsChange={v=>{setCalls(c=>[...c,v.map(x=>x.id)]);if(mode!=='reject')setItems(v)}} renderItem={x=><span>{x.id}</span>}/><button>After list</button></main>
}
createRoot(document.getElementById('root')!).render(<Fixture/>);
