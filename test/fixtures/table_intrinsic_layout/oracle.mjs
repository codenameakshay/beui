// Existing repository capture workflow; no app server or production code.
import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import {writeFile} from 'node:fs/promises';
const css = `table { border-collapse: collapse; table-layout: fixed; }
td { padding: 0; border: 0; }
.content { font-size: 0; line-height: 0; }
i { display: inline-block; height: 1px; }`;
const fixed=(key, parts, declared)=>({key, parts, declared});
const auto=(key, parts)=>({key, parts});
const filler=auto('filler', []);
const cases=[];
const add=(name, viewport, columns, floor=0, maxContentWidth=false)=>cases.push({name,viewport,columns,floor,maxContentWidth});
for(const width of [40,100,137,150,165,180,250,401]) {
  add(`mixed-${width}`, width,[fixed('fixed',[20],'100px'),auto('auto',[30,50]),filler]);
}
add('partial-declared-proportions',120,[fixed('a',[20],'100px'),fixed('b',[10],'50px'),auto('c',[30]),filler]);
add('fractional-remainder',101,[fixed('a',[20],'100px'),fixed('b',[10],'50px'),auto('c',[30]),filler]);
add('multiple-auto-growth',195,[fixed('a',[20],'100px'),auto('b',[30,50]),auto('c',[20,20]),filler]);
add('multiple-auto-surplus',340,[fixed('a',[20],'100px'),auto('b',[30,50]),auto('c',[20,20]),filler]);
add('filler-surplus',300,[fixed('a',[20],'100px'),fixed('b',[30],'50px'),filler]);
add('empty-autos-split',301,[fixed('a',[20],'100px'),auto('empty',[]),filler]);
add('no-auto-surplus',301,[fixed('a',[20],'100px'),fixed('b',[30],'50px')]);
add('fixed-pref-below-wrappable-max',110,[fixed('a',[20,20],'25px'),auto('b',[30,50]),filler]);
add('fractional-freeze',100,[fixed('name',[112.453125],'112px'),filler]);
add('resized-name',100,[fixed('name',[112.453125],'162px'),filler],0,true);
add('invalid-fr-auto',200,[fixed('a',[40,60],'1.4fr'),fixed('b',[20,30],'1.8fr'),filler]);
add('rem-preference',200,[fixed('a',[20],'8rem'),filler]);
add('table-floor-overflow',40,[fixed('a',[20],'100px'),auto('b',[30,50]),filler],220);
add('max-content-width',40,[fixed('a',[20],'100px'),auto('b',[30,50]),filler],0,true);
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
 const page=await browser.newPage({viewport:{width:1280,height:1000},deviceScaleFactor:1});
 const results=[];
 for(const c of cases){
  const html=`<!doctype html><meta charset="utf-8"><style>html{font-size:16px}${css}</style><div style="width:${c.viewport}px"><table style="min-width:max(100%, ${c.floor}px);${c.maxContentWidth?'width:max-content;':''}"><colgroup>${c.columns.map(x=>`<col${x.declared?` style="width:${x.declared}"`:''}>`).join('')}</colgroup><tr>${c.columns.map(x=>`<td><div class="content">${x.parts.map(w=>`<i style="width:${w}px"></i>`).join('<wbr>')}</div></td>`).join('')}</tr></table></div>`;
  await page.setContent(html);
  const observed=await page.evaluate(()=>({tableWidth:document.querySelector('table').getBoundingClientRect().width,widths:[...document.querySelectorAll('td')].map(e=>e.getBoundingClientRect().width),colStyles:[...document.querySelectorAll('col')].map(e=>e.style.width),computedTableLayout:getComputedStyle(document.querySelector('table')).tableLayout,computedWidth:getComputedStyle(document.querySelector('table')).width}));
  results.push({...c,columns:c.columns.map(x=>({...x,minimum:Math.max(0,...x.parts),maximum:x.parts.reduce((a,b)=>a+b,0)})),...observed});
  await writeFile(new URL(`${c.name}.html`,import.meta.url),html+'\n');
 }
 await writeFile(new URL('oracle.json',import.meta.url),JSON.stringify({browserVersion:await browser.version(),playwright:'playwright-core via documented /tmp/beui-parity-capture-runtime',css,results},null,2)+'\n');
 console.log(`Recorded ${results.length} native table cases; Chrome ${await browser.version()}`);
} finally {await browser.close();}
