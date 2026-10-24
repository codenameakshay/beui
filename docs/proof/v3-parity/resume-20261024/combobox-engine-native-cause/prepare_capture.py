from pathlib import Path
s=Path('/tmp/beui-gallery-engine-causal-r10');r=Path.cwd()/'docs/proof/v3-parity/resume-20261024/combobox-rapid-input'
recorder="""globalThis.__r10Events=[];globalThis.__r10Dropped=0;globalThis.__r10Trace=(event,detail,node)=>{if(__r10Events.length>=12000){__r10Dropped++;return;}__r10Events.push({time:performance.now(),event,detail:JSON.parse(detail),node:globalThis.__nodeId?.(node),value:node?.value,start:node?.selectionStart,end:node?.selectionEnd,direction:node?.selectionDirection,connected:node?.isConnected});};"""
for kind,src in [('initial','capture-initial-final.mjs'),('full','capture-final.mjs')]:
 t=(r/src).read_text();t=t.replace("globalThis.__inputs=[];",recorder+"globalThis.__inputs=[];")
 t=t.replace("globalThis.__inputs.push({type", "if(globalThis.__inputs.length<12000)globalThis.__inputs.push({type")
 t=t.replace("/?slug=${target}","/${process.env.BUILD||'instrumented'}/?slug=${target}")
 t=t.replace("const inputs=[...priorInputs", "trace.push(...await page.evaluate(()=>globalThis.__r10Events));const dropped=await page.evaluate(()=>__r10Dropped);check('trace bounded without drops',dropped===0,dropped);const inputs=[...priorInputs")
 (s/(kind+'.mjs')).write_text(t)
(s/'tmp').mkdir(exist_ok=True)
