import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const side = process.argv[2];
const motion = process.argv[3] ?? 'no-preference';
const touch = process.argv[4] === 'touch';
const root = 'docs/proof/v3-parity/charts/round4-bump';
const url = `http://127.0.0.1:18115/${side}/?theme=dark`;
const scriptUrl = `http://127.0.0.1:18115/${side}/${side === 'source' ? 'source.js' : 'main.dart.js'}`;
const sha256 = createHash('sha256').update(Buffer.from(await (await fetch(scriptUrl)).arrayBuffer())).digest('hex');
const name = `${side}-${motion}${touch ? '-touch' : ''}${process.env.BUMP_RUN ? `-${process.env.BUMP_RUN}` : ''}`;
const config = {
  url, viewport:{width:800,height:600}, theme:'dark', reducedMotion:motion,
  backend:'screenshots', loadWaitMs:2500, finalHoldMs:700,
  requireFlutterProbe:side !== 'source',
  stageSelector:side === 'source' ? 'main' : 'flutter-view',
  servedJs:{url:scriptUrl,sha256,revision:side === 'source' ? 'a76e57c9bbc2837e96420b2610e9c82a3271bb05' : side === 'before' ? 'a2942181 with unchanged bump and dedicated fixture' : process.env.BUMP_REVISION},
  provenance:{pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',liveDeployment:'unknown',transport:touch ? 'unchanged round3 trusted-touch wrapper' : 'native Playwright mouse and keyboard',baseline:'no originals or goldens overwritten'},
  targets:{dot:{x:137.83,y:249.14},exit:{x:30,y:30}},
  events:touch ? [
    {atMs:300,type:'click',target:'dot',caption:'Touch selects Studio'},
    {atMs:1000,type:'click',target:'dot',caption:'Second touch clears Studio'},
    {atMs:1700,type:'click',target:'dot',caption:'Third touch selects Studio'},
  ] : [
    {atMs:300,type:'move',target:'dot',caption:'Hover Studio April'},
    {atMs:700,type:'click',target:'dot',caption:'Native click pins Studio'},
    {atMs:1000,type:'move',target:'exit',caption:'Pointer exits focused dot'},
    {atMs:1300,type:'key',key:'Tab',caption:'Tab traverses to Studio May'},
    {atMs:1650,type:'key',key:'Home',caption:'Home does not select a series'},
    {atMs:1950,type:'key',key:'Enter',caption:'Enter toggles Studio'},
    {atMs:2250,type:'key',key:'Space',caption:'Space toggles Studio'},
    {atMs:2550,type:'key',key:'Escape',caption:'Escape clears pin and readout'},
    {atMs:2900,type:'key',key:'u',caption:'Replace ranks with reversed periods'},
  ],
};
await mkdir(`${root}/configs`,{recursive:true});
await mkdir(`${root}/captures`,{recursive:true});
const path = `${root}/configs/${name}.json`;
await writeFile(path,JSON.stringify(config,null,2),{flag:'wx'});
const result = spawnSync('node',['tool/parity_capture.mjs',path,`${root}/captures/${name}`],{stdio:'inherit',env:{...process.env,PARITY_PLAYWRIGHT:touch ? `${process.cwd()}/test/charts/touch_capture_round3.mjs` : '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs',...(touch ? {PARITY_TOUCH_OBSERVATION:`${root}/captures/${name}/observed-touch.json`} : {})}});
process.exitCode = result.status;
