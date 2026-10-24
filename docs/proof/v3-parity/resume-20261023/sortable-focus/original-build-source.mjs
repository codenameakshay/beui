import {build} from '/tmp/beui-charts-fixture-runtime-20261023/node_modules/esbuild/lib/main.js';
import fs from 'node:fs';
const root='/tmp/beui-sortable-undo/source';
const r=await build({absWorkingDir:root,entryPoints:['fixture.tsx'],outfile:'source.js',bundle:true,jsx:'automatic',minify:false,metafile:true,nodePaths:['/tmp/beui-charts-fixture-runtime-20261023/node_modules'],alias:{'@':root},define:{'process.env.NODE_ENV':'"production"'}});fs.writeFileSync(root+'/metafile.json',JSON.stringify(r.metafile,null,2));
