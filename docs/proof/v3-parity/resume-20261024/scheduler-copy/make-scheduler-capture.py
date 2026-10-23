from pathlib import Path
o=Path('docs/proof/v3-parity/resume-20261024/scheduler-copy');s=Path('docs/proof/v3-parity/resume-20261023/multiselect-native/capture.mjs').read_text().replace('height:800','height:1200').replace('18161:18162','18183:18184')
s=s.replace("label:document.activeElement?.getAttribute('aria-label'),value:", "label:document.activeElement?.getAttribute('aria-label'),text:document.activeElement?.textContent,value:")
a=s.index("const eq=");b=s.index("try{await page.goto",a)
s=s[:a]+"""const eq=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const active=()=>page.evaluate(()=>({text:document.activeElement?.textContent,label:document.activeElement?.getAttribute('aria-label'),role:document.activeElement?.getAttribute('role'),tag:document.activeElement?.tagName}));
const tabTo=async predicate=>{for(let i=0;i<80;i++){if(predicate(await active()))return;await page.keyboard.press('Tab');await page.waitForTimeout(70);}throw Error('Tab target unreachable '+JSON.stringify(await active()));};
"""+s[b:]
a=s.index("await point(target===");b=s.index("}catch(e)",a)
s=s[:a]+"""const initial=(await page.evaluate(()=>globalThis.__fixture)).value;
await tabTo(a=>a.label?.includes('Copy Monday hours'));await page.keyboard.press('Enter');await capture('opened');
await tabTo(a=>a.role==='checkbox'||a.tag==='INPUT');await page.keyboard.press('Space');let s=await capture('selected');
check('selected checkbox',s.aria.includes('[checked]'),s.aria);
await tabTo(a=>(a.text||a.label||'').trim()==='Apply');await page.keyboard.press('Enter');s=await capture('applied');
check('one callback',s.fixture.calls.length===1,s.fixture.calls);
if(s.fixture.calls.length){const next=s.fixture.calls[0];for(const day of Object.keys(initial)){check('payload '+day,day==='tue'?next[day].enabled===initial.mon.enabled&&eq(next[day].ranges.map(r=>[r.start,r.end]),initial.mon.ranges.map(r=>[r.start,r.end])):eq(next[day],initial[day]),next[day]);}check('controlled owner',eq(s.fixture.value,owner==='accept'?next:initial),s.fixture.value);}
check('panel closed',!s.aria.includes('Copy times to'),s.aria);
await page.keyboard.press('Tab');await capture('post-apply-tab');
await tabTo(a=>a.label?.includes('Copy Monday hours'));await page.keyboard.press('Enter');await capture('reopened');
await tabTo(a=>(a.text||a.label||'').trim()==='Every day');await page.keyboard.press('Space');s=await capture('everyday');
check('second callback',s.fixture.calls.length===2,s.fixture.calls);
if(s.fixture.calls.length===2){for(const day of Object.keys(initial))check('everyday '+day,s.fixture.calls[1][day].enabled===initial.mon.enabled&&eq(s.fixture.calls[1][day].ranges.map(r=>[r.start,r.end]),initial.mon.ranges.map(r=>[r.start,r.end])),s.fixture.calls[1][day]);}
await page.keyboard.press('Tab');await capture('post-everyday-tab');
""" +s[b:]
o.joinpath('capture.mjs').write_text(s)
