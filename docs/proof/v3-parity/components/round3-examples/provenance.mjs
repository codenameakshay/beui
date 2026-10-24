import {readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {join,resolve} from 'node:path';

const repo=resolve(import.meta.dirname,'../../../../..');
const git=(...args)=>execFileSync('git',args,{cwd:repo,encoding:'utf8'}).trim();
const paths=git('ls-files','lib','example/lib').split('\n');
paths.push('docs/proof/v3-parity/components/round3-examples/candidate.dart');
const files=[];
for(const path of paths)files.push({path,sha256:createHash('sha256').update(await readFile(join(repo,path))).digest('hex')});
await writeFile(join(import.meta.dirname,'build-provenance.json'),JSON.stringify({
  implementationRevision:git('rev-parse','HEAD'),sourceRevision:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',
  flutter:'3.47.1',dart:'3.13.1',entrypoint:'candidate.dart',
  builds:[
    {label:'frozen-before',revision:'73e0d768+example-selection',note:'Original component behavior with an isolated example-selection entrypoint; not the untouched gallery bundle.',servedJs:'served-js/before-main.dart.js',sha256:'3f0da5e684b2f3a342316c79900fd5fcef569e09c709245e2d40a0b62449f770'},
    {label:'state-slider-and-initial-table-repairs',revision:'2af952c5',servedJs:'served-js/after-main.dart.js',sha256:'aad35cf010d8f9ccf6ac3972a4bd6d4e238c7e6cc09e208ead46199720d54574',headRebuild:'byte-identical, verification/beui-round3-build-head.log'},
    {label:'final-table-pointer-repairs',revision:'4935b8de',servedJs:'served-js/after-pointer-main.dart.js',sha256:'ff5f4bf1d9e3cc8de34a546580139545f4f2830a621fa54d5fe209ea6af5937d'},
    {label:'disabled-api-followup',revision:'4162ac76',servedJs:'served-js/after-disabled-main.dart.js',sha256:createHash('sha256').update(await readFile(join(import.meta.dirname,'served-js/after-disabled-main.dart.js'))).digest('hex')},
    {label:'metallic-small-icon-followup',revision:'69d0030c',servedJs:'served-js/after-metallic-size-main.dart.js',sha256:createHash('sha256').update(await readFile(join(import.meta.dirname,'served-js/after-metallic-size-main.dart.js'))).digest('hex')},
    {label:'wave-bubble-disabled-api-followup',revision:'6a8ed389c',servedJs:'served-js/after-wave-bubble-guard-main.dart.js',sha256:'c806db78695ebdbc4576890ad6abb709065958c8a622460e0827b69498fcf957'},
    {label:'historical-in-progress-repairs',revision:'uncommitted intermediate build; not a committed-head claim',servedJs:'served-js/after-intermediate-main.dart.js',sha256:'f08bb3648c241b52dd56a67c10f41d857a63fc37ddbbc3e39c66b5c5149dc530'},
    {label:'historical-in-progress-table-repairs',revision:'uncommitted intermediate build; not a committed-head claim',servedJs:'served-js/after-intermediate-v3-main.dart.js',sha256:'bd611c68585ce4f51fedbe1004f410b381c24c1fba595fc3d233293b66501f8a'},
    {label:'superseded-source-fixture-v1',revision:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',note:'Missing font weights and font readiness. Retained for historical observations, not canonical source geometry.',servedJs:'served-js/source-v1.js',sha256:'723c4c94566a7077dab3769a4fce2b7d39d7f055c199727fdb2b3b00240fbe43'},
    {label:'pinned-source-fixture-v2',revision:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',servedJs:'served-js/source.js',sha256:'c31b6542667d935f84871670d76b84013a0214c409e7ce8eed44e67afebbe7d4'},
  ],files,liveDeploymentRevision:'unknown',integratedParentVerification:'not performed by this worker',
},null,2)+'\n');
