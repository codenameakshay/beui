import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const [sourceUrl,candidateUrl,output]=process.argv.slice(2);
await mkdir(output);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const result=[];
try{
  for(const theme of ['dark','light']){
    const pair=[];
    for(const source of [true,false]){
      const page=await browser.newPage({viewport:{width:1280,height:800},reducedMotion:'reduce'});
      await page.goto(`${source?sourceUrl:candidateUrl}?theme=${theme}`);await page.waitForTimeout(3000);
      await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);
      for(const quarter of ['Q3','Q2']){
        if(quarter==='Q2'){await page.mouse.click(280,232);await page.waitForTimeout(500);}
        const nodes=await page.evaluate(()=>[...document.querySelectorAll('button,[role=button]')].filter(e=>/^(Subscriptions|Services|Marketplace|Revenue|Gross profit|Operating profit|R&D|Sales & marketing|G&A|Cost of revenue)\./.test(e.getAttribute('aria-label')||e.textContent)).map(e=>({label:e.getAttribute('aria-label')||e.textContent,rect:e.getBoundingClientRect().toJSON()})));
        assert.equal(nodes.length,10);
        pair.push({source,theme,quarter,nodes});
        await page.screenshot({path:`${output}/${source?'source':'after'}-${theme}-${quarter}.png`});
      }
      await page.close();
    }
    for(const quarter of ['Q3','Q2']){
      const source=pair.find(x=>x.source&&x.quarter===quarter),after=pair.find(x=>!x.source&&x.quarter===quarter);
      const deltas=source.nodes.map(n=>{
        const a=after.nodes.find(x=>x.label===n.label);assert.ok(a,`Missing node ${n.label}`);
        const delta=Object.fromEntries(['x','y','width','height'].map(k=>[k,a.rect[k]-n.rect[k]]));
        for(const d of Object.values(delta))assert.ok(Math.abs(d)<.03,`${n.label} DOM geometry delta ${JSON.stringify(delta)}`);
        return {label:n.label,delta};
      });
      result.push({theme,quarter,toleranceLogicalPixels:.03,source,after,deltas});
    }
  }
}finally{await writeFile(`${output}/geometry.json`,JSON.stringify(result,null,2));await browser.close();}
