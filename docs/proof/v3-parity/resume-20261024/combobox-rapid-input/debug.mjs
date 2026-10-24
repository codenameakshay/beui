import {chromium} from './runtime/node_modules/playwright-core/index.mjs';
import fs from 'node:fs';
const b=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});const p=await b.newPage();p.on('console',m=>console.log(m.type(),m.text()));p.on('pageerror',console.log);await p.goto(`http://127.0.0.1:${JSON.parse(fs.readFileSync('/tmp/beui-rapid-input-20261024/server.json')).port}/?slug=combobox&captureProbe=1`);await p.waitForTimeout(4000);await b.close();
