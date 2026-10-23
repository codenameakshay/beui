import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const [url,output]=process.argv.slice(2);
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const fixtures=[];
try{
  const page=await browser.newPage({viewport:{width:1280,height:800},reducedMotion:'reduce'});
  await page.goto(url);await page.waitForTimeout(3000);
  for(const quarter of ['q3','q2']){
    if(quarter==='q2'){await page.mouse.click(280,232);await page.waitForTimeout(500);}
    const paths=await page.evaluate(()=>[...document.querySelector('[data-slot=sankey-chart-plot] svg > g').querySelectorAll('path')].map(p=>({d:p.getAttribute('d'),length:p.getTotalLength(),samples:[0,.25,.5,.75,1].map(f=>{const v=p.getPointAtLength(p.getTotalLength()*f);return {fraction:f,x:v.x,y:v.y};})})));
    assert.equal(paths.length,9);fixtures.push({quarter,width:768,height:320,paths});
  }
  await writeFile(output,JSON.stringify({pin:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',url,fixtures},null,2),{flag:'wx'});
}finally{await browser.close();}
