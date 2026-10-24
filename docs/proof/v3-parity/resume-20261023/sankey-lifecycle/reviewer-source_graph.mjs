import {build} from '/tmp/beui-sankey-runtime-20261023/node_modules/esbuild/lib/main.js';
import {writeFileSync} from 'node:fs';
const compiled=await build({entryPoints:['/tmp/beui-charts-reference-20261023/components/charts/sankey-chart/model.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {cleanSankey,layoutSankey,SANKEY_COLORS}=await import(`data:text/javascript;base64,${Buffer.from(compiled.outputFiles[0].contents).toString('base64')}`);
let seed=4271;const rnd=n=>{seed=(seed*1664525+1013904223)>>>0;return seed%n;};
const fixtures=[];
for(let k=0;k<100;k++){
 const nodes=Array.from({length:2+rnd(8)},(_,i)=>({id:String(i),label:String(i)}));nodes.push({...nodes[0],label:'Duplicate'});
 const links=Array.from({length:5+rnd(24)},()=>({source:String(rnd(nodes.length+1)),target:String(rnd(nodes.length+1)),value:rnd(20)-2,...(rnd(3)===0?{id:String(rnd(5))}:{})}));
 const data=cleanSankey(nodes,links);const l=layoutSankey(data,{width:640,height:320,nodeWidth:12,nodePadding:16,colors:SANKEY_COLORS});
 fixtures.push({nodes,links,cleaned:data,layout:{nodes:l.nodes,links:l.links.map(({source,target,...rest})=>({...rest,source:source.id,target:target.id})),columns:l.columns,step:l.step}});
}
writeFileSync('/tmp/sankey-independent-review-20261023/source_graph.json',JSON.stringify(fixtures));
