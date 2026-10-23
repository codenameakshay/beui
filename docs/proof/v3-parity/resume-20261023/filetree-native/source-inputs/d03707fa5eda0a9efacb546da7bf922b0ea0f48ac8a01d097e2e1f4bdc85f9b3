import React,{useState,useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {FileTree,FileTreeFolder,FileTreeFile} from '/tmp/beui-charts-reference-20261023/components/motion/file-tree';
function Fixture(){const [expanded,setExpanded]=useState<string[]>([]),[value,setValue]=useState('none'),[calls,setCalls]=useState<string[]>([]),[expCalls,setExpCalls]=useState<string[][]>([]);
useEffect(()=>{const onKey=(e:KeyboardEvent)=>{if(e.key==='c')setExpanded([])};window.addEventListener('keydown',onKey);return()=>window.removeEventListener('keydown',onKey)},[]);
(globalThis as any).__fixture={expanded,value,calls,expCalls,disableAnimations:matchMedia('(prefers-reduced-motion: reduce)').matches};
return <main style={{width:480}}><p>Supplemental FileTree. C externally collapses all folders.</p><button>Before</button><FileTree value={value} expandedIds={expanded} onValueChange={v=>{setValue(v);setCalls(a=>[...a,v])}} onExpandedChange={v=>{setExpanded(v);setExpCalls(a=>[...a,v])}}><FileTreeFolder value="parent" name="Parent"><FileTreeFolder value="folder" name="Folder"><FileTreeFile value="leaf" name="Leaf"/><FileTreeFile value="disabled" name="Disabled" disabled/><FileTreeFile value="sibling" name="Sibling"/></FileTreeFolder><FileTreeFile value="peer" name="Peer"/></FileTreeFolder><FileTreeFile value="tail" name="Tail"/></FileTree><button>After</button></main>}
createRoot(document.getElementById('root')!).render(<Fixture/>);
