import { readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { join, resolve } from 'node:path';

const root = import.meta.dirname;
for (const theme of ['light','dark']) {
  const config = JSON.parse(await readFile(join(root,'verified','configs',`source-${theme}.json`)));
  config.stageSelector = 'div.flex.items-center.justify-center.py-10';
  const path = join(root,`source-${theme}-final-config.json`);
  await writeFile(path,JSON.stringify(config,null,2));
  const result = spawnSync(process.execPath,[resolve('tool/parity_capture.mjs'),path,join(root,`source-${theme}-final`)],{encoding:'utf8',env:{...process.env,PARITY_PLAYWRIGHT:'/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs'}});
  await writeFile(join(root,`source-${theme}-final.log`),result.stdout+result.stderr);
  if (result.status !== 0) throw new Error(result.stdout+result.stderr);
  console.log(theme,result.stdout);
}
