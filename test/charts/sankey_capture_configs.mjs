import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const [sourcePath,candidatePath,output]=process.argv.slice(2);
await mkdir(output);
const revision=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
const sha=async p=>createHash('sha256').update(await readFile(p)).digest('hex');
for(const source of [true,false])for(const reduce of [false,true])for(const entrance of [false,true]){
  const theme=reduce?'light':'dark', reducedMotion=reduce?'reduce':'no-preference';
  const base=source?'source-v6':'fixture-proof';
  const url=`http://127.0.0.1:18119/${base}/?theme=${theme}`;
  const javascript=source?'source.js':'main.dart.js';
  const config={url,viewport:{width:1280,height:800},theme,reducedMotion,reference:false,requireFlutterProbe:!source,backend:'screenshots',loadWaitMs:3000,
    servedJs:{url:`http://127.0.0.1:18119/${base}/${javascript}`,sha256:await sha(`${source?sourcePath:candidatePath}/${javascript}`),revision:source?'a76e57c9bbc2837e96420b2610e9c82a3271bb05':revision},
    provenance:{pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',implementationRevision:revision,sourceLiveDeployment:'unknown',recorderSha256:await sha('tool/parity_capture.mjs'),timerOverrides:'none',mode:entrance?'native reload entrance':'native pointer, Q2 change and keyboard'},
    targets:{node:{x:262,y:380},flow:{x:400,y:380},q2:{x:280,y:232},exit:{x:50,y:50}},
    events:entrance?[{atMs:250,type:'key',key:'ControlOrMeta+R'}]:[
      {atMs:200,type:'move',target:'node'},
      {atMs:650,type:'move',target:'flow'},
      {atMs:1100,type:'move',target:'exit'},
      {atMs:1400,type:'click',target:'q2'},
      {atMs:2300,type:'click',target:'node'},
      {atMs:2700,type:'key',key:'ArrowRight'},
      {atMs:3100,type:'key',key:'End'},
      {atMs:3500,type:'key',key:'Escape'},
    ],finalHoldMs:entrance?4500:700};
  await writeFile(`${output}/${source?'source':'after'}-${theme}-${reducedMotion}-${entrance?'entrance':'input'}.json`,JSON.stringify(config,null,2),{flag:'wx'});
}
