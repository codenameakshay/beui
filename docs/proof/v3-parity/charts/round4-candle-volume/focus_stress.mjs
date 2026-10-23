import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
const [output, trials = '12'] = process.argv.slice(2);
const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const rows = [];
try {
  for(let i=0;i<Number(trials);i++) {
    const context = await browser.newContext({viewport:{width:1280,height:1000}});
    const page = await context.newPage();
    await page.addInitScript(() => {
      globalThis.__focusInputs = [];
      for(const type of ['pointerdown','pointerup','keydown']) document.addEventListener(type,e=>globalThis.__focusInputs.push({type,key:e.key,target:e.target.tagName,time:performance.now(),trusted:e.isTrusted}),true);
    });
    await page.goto('http://127.0.0.1:18114/?chart=volume&theme=dark&width=576');
    await page.waitForTimeout(2000);
    await page.locator('flt-semantics-placeholder').evaluateAll(nodes=>nodes.forEach(n=>n.click()));
    await page.mouse.move(620,471);
    await page.waitForTimeout(200);
    await page.mouse.move(722,432);
    await page.waitForTimeout(200);
    await page.mouse.move(1100,200);
    await page.mouse.click(620,471);
    await page.mouse.move(1100,200);
    await page.keyboard.press('Home');
    await page.waitForTimeout(400);
    const values = await page.locator('[aria-valuetext]').evaluateAll(nodes=>nodes.map(n=>n.getAttribute('aria-valuetext')));
    const diagnostic = await page.evaluate(()=>({probe:globalThis.__beuiCapture,inputs:globalThis.__focusInputs}));
    rows.push({i,values,pass:values[0]?.startsWith('$64,000 to $64,100.'),diagnostic});
    console.log({i,values,pass:rows.at(-1).pass,diagnostic});
    await context.close();
  }
} finally {await browser.close();}
await writeFile(output,JSON.stringify(rows,null,2),{flag:'wx'});
console.log(JSON.stringify(rows));
if(rows.some(row=>!row.pass))process.exitCode=1;
