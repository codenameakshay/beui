import React,{useState} from 'react';
import {createRoot} from 'react-dom/client';
import {MultiSelect,MultiSelectTrigger,MultiSelectValue,MultiSelectInput,MultiSelectContent,MultiSelectList,MultiSelectItem,MultiSelectEmpty} from '@/components/motion/multi-select';
const reject=new URLSearchParams(location.search).get('owner')==='reject';
function Fixture(){const [value,setValue]=useState(['alpha','beta','gamma']);const [calls,setCalls]=useState<string[][]>([]);const [query,setQuery]=useState('');const [open,setOpen]=useState(false);
(globalThis as any).__fixture={value,calls,query,open,reject,disableAnimations:matchMedia('(prefers-reduced-motion: reduce)').matches};
return <div style={{width:480,alignSelf:'flex-start',marginTop:100}}><p>Supplemental MultiSelect {reject?'reject':'accept'} owner</p><MultiSelect value={value} onValueChange={v=>{setCalls(c=>[...c,v]);if(!reject)setValue(v)}} onQueryChange={setQuery} onOpenChange={setOpen}><MultiSelectTrigger><MultiSelectValue/><MultiSelectInput aria-label="Search options"/></MultiSelectTrigger><MultiSelectContent><MultiSelectList>{[['alpha','Alpha'],['disabled','Disabled'],['beta','Beta'],['gamma','Gamma'],['delta','Delta']].map(([v,l])=><MultiSelectItem key={v} value={v} textValue={l} disabled={v==='disabled'}>{l}</MultiSelectItem>)}<MultiSelectEmpty>No options found.</MultiSelectEmpty></MultiSelectList></MultiSelectContent></MultiSelect></div>}
createRoot(document.getElementById('root')!).render(<Fixture/>);
