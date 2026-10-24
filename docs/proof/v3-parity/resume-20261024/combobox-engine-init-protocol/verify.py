from pathlib import Path
import hashlib,json,re
p=Path(__file__).resolve().parent
for name,digest in json.loads((p/'SHA256SUMS.json').read_text()).items():
 assert hashlib.sha256((p/name).read_bytes()).hexdigest()==digest,name
for name,digest in json.loads((p/'original-engine-hashes.json').read_text()).items():
 assert hashlib.sha256((p/'source/lib/src/engine'/name).read_bytes()).hexdigest()==digest,name
results=json.loads((p/'results.json').read_text())
for name,expected in results.items():
 s=(p/'logs'/f'{name}.log').read_text()
 counts=re.findall(r'\+(\d+) ~(\d+) -(\d+): Some tests failed',s)[-1]
 assert list(map(int,counts))==[expected['passed'],expected['skipped'],expected['failed']]
 failures=[re.sub(r'^.*?: (semantics/|text_editing)',r'\1',line).strip() for line in s.splitlines() if '[E]' in line]
 assert failures==expected['failures']
 traces=json.loads((p/f'{name}-traces.json').read_text())
 assert len(traces)==expected['traces']
 for initial in ['', 'Design studio']:
  pair=[t for t in traces if t['initial']==initial and t['emptyUpdate']]
  assert len(pair)==2 and {t['ownerWins'] for t in pair}=={True,False}
  def commands(t):
   return [{k:v for k,v in e.items() if k!='us'} for e in t['trace'] if e['event']=='framework.send']
  assert commands(pair[0])==commands(pair[1]),'owner intent absent from channel'
assert results['final-uninstrumented']['passed']==157
assert results['final-uninstrumented']['failed']==12
assert results['final-uninstrumented']['skipped']==5
assert json.loads((p/'final-run.json').read_text())['exit']==1
assert json.loads((p/'process-cleanup.json').read_text())['ownedProcesses']==[]
print('PASS: archive integrity, original engine identity, retained red outcomes, and legacy-command ambiguity. No safe candidate or native qualification is claimed.')
