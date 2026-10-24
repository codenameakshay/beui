from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for f,h in json.loads((r/'SHA256SUMS.json').read_text()).items():assert sha(r/f)==h,f
for f,h in json.loads((r/'copied-inputs.json').read_text()).items():assert sha(r/'inputs'/f)==h,f
assert json.loads((r/'copied-inputs.json').read_text())['lib/src/motion/combobox.dart']=='ef7c79680a7208f9c593287a50fc30949b78e359b640a97aa78f9f7e4d316d97'
for build in ['instrumented','baseline']:
 manifest=json.loads((r/(build+'-build-manifest.json')).read_text());assert manifest==json.loads((r/(build+'-served.json')).read_text())
 for f,h in manifest.items():assert sha(r/'web'/build/f)==h
causal=[]; baseline_losses=[];counts={};actual_failures={}
for p in sorted(r.glob('*-*/*/results.json')):
 d=json.loads(p.read_text());build=p.parent.parent.name.split('-')[0];counts[build]=counts.get(build,0)+1
 assert not d['errors'],str(p)
 assert all(x['isTrusted'] or (x['type']=='click' and x['tag']=='FLT-SEMANTICS-PLACEHOLDER') for x in d['inputs'])
 failed=[x['name'] for x in d['checks'] if not x['pass']];actual_failures[str(p.relative_to(r))]=failed
 assert all(x in ['initial-type retained','initial-type exact options','retained initial query','filtered retained','filtered exact options','filter Product'] for x in failed),failed
 for f in d['frames']:assert sha(p.parent/f['file'])==f['sha256']
 for state in d['states']:assert sha(p.parent/state['screenshot']['file'])==state['screenshot']['sha256']
 for served in d['scripts']:
  assert sha(r/'served'/served['sha256'])==served['sha256']
  if served['url'].endswith('/main.dart.js'):assert served['sha256']==sha(r/'web'/build/'main.dart.js')
 trace=d['trace'];state=next(x for x in d['states'] if x['name'] in ['initial-type','filtered'])
 if build=='baseline':
  assert not trace
  if state['focus']['value']!='Product':baseline_losses.append(str(p.relative_to(r)))
  continue
 activate=next(x for x in trace if x['event']=='semantics.activate');replay=next(x for x in trace if x['event']=='DOM.apply')
 early=[x for x in d['inputs'] if x['type']=='input' and x['time']<activate['time']]
 if state['focus']['value']=='Product':continue
 assert early and all(x['isTrusted'] and x['connected'] and x['node']==activate['node'] for x in early)
 assert activate['detail']['enabled']==False and activate['detail']['listeners']==0
 assert not [x for x in trace if x['event'] in ['engine.handleChange','channel.update','framework.updateEditingValue','combo.onChanged'] and x['time']<activate['time']]
 install=next(x for x in trace if x['event']=='listener.add' and x['detail']['type']=='input' and x['node']==activate['node'])
 assert early[-1]['time']<activate['time']<=install['time']<=replay['time']
 assert replay['node']==activate['node'] and replay['value']==early[-1]['value'] and replay['detail']['new']==''
 assert any(x['event']=='framework.controller' and x['detail']['new']=='' and early[0]['time']<x['time']<activate['time'] for x in trace)
 for ev in ['channel.update','framework.updateEditingValue','combo.onChanged']:
  later=[x for x in trace if x['event']==ev and replay['time']<x['time']<state.get('time',1e99)]
  # The all-characters-lost case has no input left before Escape; other cases deliver their suffix.
  if state['focus']['value']:assert any(x['detail'].get('text')==state['focus']['value'] for x in later)
 causal.append(str(p.relative_to(r)))
assert len(causal)>=4 and baseline_losses
assert actual_failures==json.loads((r/'expected-failures.json').read_text())
assert counts=={'baseline':14,'instrumented':14},counts
print(json.dumps({'integrity':'pass','causalFailures':causal,'baselineLosses':baseline_losses,'captures':counts,'acceptance':'initial-entry unresolved'},indent=2))
