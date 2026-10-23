import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const root = import.meta.dirname;
const out = join(root,'native-replay');
await mkdir(out);
const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const results = [];
try {
  for (const theme of ['light','dark']) for (const phase of ['before','after']) {
    const config = JSON.parse(await readFile(join(root,'configs',`${phase}-${theme}.json`)));
    for (const [count,expected] of [[5,'Open'],[6,'Open'],[8,'All'],[9,'Closed'],[10,'Open']]) {
      const context = await browser.newContext({viewport:config.viewport,deviceScaleFactor:1,colorScheme:theme,reducedMotion:'no-preference'});
      const page = await context.newPage();
      await page.goto(config.url);
      await page.waitForTimeout(5000);
      for (const event of config.events.slice(0,count)) {
        const target = config.targets[event.target];
        if (event.type === 'move') await page.mouse.move(target.x,target.y);
        if (event.type === 'down') {await page.mouse.move(target.x,target.y);await page.mouse.down();}
        if (event.type === 'up') await page.mouse.up();
        if (event.type === 'key') await page.keyboard.press(event.key);
        await page.waitForTimeout(250);
      }
      await page.waitForTimeout(900);
      const id = `${phase}-${theme}-${count}`;
      await page.screenshot({path:join(out,`${id}.png`)});
      const activeBeforeObservation = await page.evaluate(()=>document.activeElement?.outerHTML);
      await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      await page.waitForTimeout(200);
      const buttons = await page.locator('flt-semantics[role=button]').evaluateAll(es=>es.filter(e=>['All','Open','Closed'].includes(e.textContent)).map(e=>({name:e.textContent,selected:e.getAttribute('aria-current'),rect:e.getBoundingClientRect().toJSON()})));
      const selected = buttons.filter(e=>e.selected === 'true').map(e=>e.name);
      assert.deepEqual(selected,[expected],`${id} native keyboard result`);
      results.push({id,events:config.events.slice(0,count),expected,selected,buttons,activeBeforeObservation,observation:'Screenshot taken before enabling semantics. Semantics enabled only after the final native action to read selection. Each checkpoint uses a fresh context.'});
      await writeFile(join(out,'results.json'),JSON.stringify(results,null,2));
      console.log(id,selected);
      await context.close();
    }
  }
} finally {await browser.close();}
