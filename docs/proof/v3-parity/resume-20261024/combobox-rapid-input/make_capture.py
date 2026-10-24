from pathlib import Path
s=Path('docs/proof/v3-parity/resume-20261024/three-components-native/capture.mjs').read_text()
s=s.replace("['collapsible','combobox','availability-scheduler']","['combobox']")
s=s.replace("const reads=[],scripts=[]", "const trace=[];page.on('console',m=>{if(m.text().startsWith('COMBO_TRACE '))trace.push({received:Date.now(),...JSON.parse(m.text().slice(12))})});const reads=[],scripts=[]")
a=s.index('await page.addInitScript(');b=s.index('\nconst cdp=',a)
s=s[:a]+'''await page.addInitScript(()=>{globalThis.__inputs=[];let seq=0;const ids=new WeakMap();globalThis.__nodeId=n=>{if(!n)return null;if(!ids.has(n))ids.set(n,++seq);return ids.get(n)};for(const type of ['keydown','keyup','pointerdown','pointerup','click','focusin','focusout','beforeinput','input','compositionstart','compositionend'])window.addEventListener(type,e=>{const n=e.target;globalThis.__inputs.push({type,key:e.key,isTrusted:e.isTrusted,time:performance.now(),node:__nodeId(n),connected:n.isConnected,tag:n.tagName,label:n.getAttribute?.('aria-label'),value:n.value,start:n.selectionStart,end:n.selectionEnd,data:e.data,inputType:e.inputType});},true)});'''+s[b:]
s=s.replace("value:a?.value}","value:a?.value,node:globalThis.__nodeId(a)}")
s=s.replace('target,reducedMotion,browser:browser.version(),scripts,states', 'target,reducedMotion,trace,browser:browser.version(),scripts,states')
s=s.replace("await page.keyboard.type('Pro');s=await capture('rapid-reopen');", "await page.keyboard.type(process.env.QUERY||'Pro');s=await capture('rapid-reopen');check('retained rapid query',s.focus.value===(process.env.QUERY||'Pro'),s.focus);check('rapid panel open',s.aria.includes('group \\\"Workspaces\\\"'),s.aria);\nawait page.keyboard.press('Escape');await page.keyboard.press('ArrowDown');s=await capture('arrow-control');check('arrow panel open',s.aria.includes('group \\\"Workspaces\\\"'),s.aria);")
Path('/tmp/beui-rapid-input-20261024/capture.mjs').write_text(s)
