import {readFile,writeFile,copyFile,constants} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root='docs/proof/v3-parity/charts/round4-bump';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const name of ['inputs.json','package-lock.json'])await copyFile(`/tmp/beui-bump-r4-source-20261023-v2/${name}`,`${root}/source-${name}`,constants.COPYFILE_EXCL);
await copyFile('example/assets/fonts/OFL.txt',`${root}/source-fonts/OFL.txt`,constants.COPYFILE_EXCL);
const paths=[
  'lib/src/charts/bump_chart.dart','example/lib/demos/bump_chart_demo.dart','test/charts/bump_parity_fixture.dart',
  'lib/src/charts/_shared.dart','lib/src/motion/tooltip.dart','lib/src/motion/_engine.dart','lib/src/tokens/motion.dart',
  'lib/src/theme/beui_colors.dart','lib/src/theme/beui_colors.g.dart','lib/src/theme/beui_text_theme.dart',
  'example/assets/fonts/Geist-Regular.ttf','example/assets/fonts/Geist-Medium.ttf','example/assets/fonts/GeistMono-Regular.ttf','example/assets/fonts/GeistMono-Medium.ttf',
  'example/pubspec.yaml','example/pubspec.lock','pubspec.yaml','pubspec.lock',
  'tool/parity_capture.mjs','tool/parity_capture_config.mjs','test/charts/touch_capture_round3.mjs',
  '/tmp/beui-charts-reference-20261023/app/globals.css',
];
const files=[];
for(const path of paths){const bytes=await readFile(path);files.push({path,bytes:bytes.length,sha256:hash(bytes)});}
const builds=[];
for(const [side,directory,script,revision]of[
  ['before','/tmp/beui-bump-r4-before-20261023','main.dart.js','a2942181 with the dedicated fixture'],
  ['source','/tmp/beui-bump-r4-source-20261023-v2','source.js','a76e57c9bbc2837e96420b2610e9c82a3271bb05 with consumer wrapper and separately identified live font responses'],
  ['after','/tmp/beui-bump-r4-after-20261023-v11','main.dart.js','888fa569'],
]){
  const bytes=await readFile(`${directory}/${script}`);
  builds.push({side,directory,script,revision,sha256:hash(bytes),bytes:bytes.length});
}
await writeFile(`${root}/build-inputs.json`,JSON.stringify({pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',sourceDeploymentRevision:'unknown',server:'127.0.0.1:18115',htmlWrapper:'The server replaces only the generated HTML base href with the before or after prefix. JavaScript bytes are unchanged.',files,builds},null,2),{flag:'wx'});
