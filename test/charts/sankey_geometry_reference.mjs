import {build} from '/tmp/beui-sankey-runtime-20261023/node_modules/esbuild/lib/main.js';
import {writeFile} from 'node:fs/promises';
const module=await build({entryPoints:['/tmp/beui-charts-reference-20261023/components/charts/sankey-chart/model.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {cleanSankey,layoutSankey,SANKEY_COLORS}=await import(`data:text/javascript;base64,${Buffer.from(module.outputFiles[0].contents).toString('base64')}`);
const nodes=[{id:'ads',label:'Ads'},{id:'search',label:'Search'},{id:'signup',label:'Signup'},{id:'paid',label:'Paid'},{id:'free',label:'Free'}];
const links=[{source:'ads',target:'signup',value:30},{source:'search',target:'signup',value:50},{source:'search',target:'signup',value:20},{source:'signup',target:'paid',value:40},{source:'signup',target:'free',value:60},{source:'paid',target:'ads',value:5}];
const fixtures=[];
for(const [width,height,nodeWidth,nodePadding] of [[640,320,12,16],[512,180,8,80],[768,320,12,16]]){
  const data=cleanSankey(nodes,links),layout=layoutSankey(data,{width,height,nodeWidth,nodePadding,colors:SANKEY_COLORS});
  fixtures.push({nodes,links,width,height,nodeWidth,nodePadding,cleaned:data,layout});
}
await writeFile('docs/proof/v3-parity/charts/sankey/source/geometry.json',JSON.stringify({source:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',fixtures},null,2),{flag:'wx'});
