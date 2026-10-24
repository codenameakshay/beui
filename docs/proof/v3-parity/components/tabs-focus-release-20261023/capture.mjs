import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { join, resolve } from 'node:path';

const root = import.meta.dirname;
await mkdir(join(root,'configs'));
const retained = resolve('docs/proof/v3-parity/components/underline-release-20261023');
for (const reducedMotion of ['no-preference','reduce']) for (const theme of ['light','dark']) for (const phase of ['source','before','after']) {
  const source = phase === 'source';
  const input = JSON.parse(await readFile(join(retained,source?`source-${theme}-final/config.json`:`after-${theme}/config.json`)));
  const id = `${phase}-${theme}-${reducedMotion}`;
  const port = phase === 'before'?8112:8113;
  const revision = phase === 'before'?'ce5564d267cc4bb98b258bbf27f4689ee48db8e9':'bd6df4189ebcfee751c453d1ff575b07bb417fbc';
  const response = source?null:await fetch(`http://127.0.0.1:${port}/main.dart.js`);
  const sha256 = source?null:createHash('sha256').update(Buffer.from(await response.arrayBuffer())).digest('hex');
  if (!source && response.status!==200) throw new Error(`Missing ${phase} build`);
  const events = [
    {atMs:500,type:'move',target:'open'},
    {atMs:1000,type:'down',target:'open'},
    {atMs:1250,type:'up',target:'open'},
    {atMs:1800,type:'move',target:'outside'},
    {atMs:2100,type:'key',key:'End'},
    {atMs:3000,type:'key',key:'ArrowLeft'},
  ];
  if (source) {
    for (const event of events) event.atMs+=1000;
    events.unshift({atMs:0,type:'click',target:'theme'});
  }
  const config = {...input,
    url:source?input.url:`http://127.0.0.1:${port}/?slug=tabs&theme=${theme}&color=Blue&previewWidth=592&captureProbe=1`,
    reference:false,reducedMotion,events,finalHoldMs:1000,
    servedJs:source?undefined:{url:`http://127.0.0.1:${port}/main.dart.js`,sha256,revision},
    provenance:{phase,revision:source?'unknown live deployment; pinned correspondence a76e57c9bbc2837e96420b2610e9c82a3271bb05':revision,
      wrapper:source?'Live documentation stage, 592px preview, 448px demo':'Unmodified visual_harness.dart, previewWidth=592, 448px demo',
      nativeInput:'No semantics enabled during recorder input. Identical native pointer, End, ArrowLeft sequence. Source theme click after hydration.'},
  };
  const path=join(root,'configs',`${id}.json`);
  await writeFile(path,JSON.stringify(config,null,2));
  const result=spawnSync(process.execPath,[resolve('tool/parity_capture.mjs'),path,join(root,id)],{encoding:'utf8',maxBuffer:10000000,env:{...process.env,PARITY_PLAYWRIGHT:'/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs'}});
  await writeFile(join(root,`${id}.log`),result.stdout+result.stderr);
  if (result.status!==0) throw new Error(result.stdout+result.stderr);
  console.log(id,result.stdout);
}
