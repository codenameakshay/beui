from pathlib import Path
import json,hashlib,tarfile,subprocess
R=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
seal=json.loads((R/'archive-sha256.json').read_text())
for name,h in seal.items():
 p=R/name
 assert p.is_file() and not p.is_symlink(),name
 assert sha(p.read_bytes())==h,name
for archive in R.glob('*.tar.gz'):
 with tarfile.open(archive) as t:
  assert all(m.isfile() or m.isdir() for m in t),archive
for manifest,archive in [('candidate-inputs.json','candidate-input-originals.tar.gz')]:
 with tarfile.open(R/archive) as t:
  for p,h in json.loads((R/manifest).read_text()).items():assert sha(t.extractfile(p).read())==h,p
with tarfile.open(R/'source-input-originals.tar.gz') as t:
 for x in json.loads((R/'source-inputs.json').read_text())['inputs']:assert sha(t.extractfile(x['archivePath']).read())==x['sha256']
assert all(x['matches'] for x in json.loads((R/'pinned-input-check.json').read_text()))
results=[]
for p in sorted((R/'attempt-3').glob('*/results.json')):
 r=json.loads(p.read_text());states={s['name']:s for s in r['states']}
 assert len(states)==21,(p,len(states))
 assert all(c['pass'] for c in r['checks']),p
 assert all(e['isTrusted'] or (e['type']=='click' and e['x']==0 and e['y']==0) for e in r['inputs'])
 for s in r['states']:assert sha((p.parent/s['screenshot']['file']).read_bytes())==s['screenshot']['sha256']
 for f in r['frames']:assert sha((p.parent/f['file']).read_bytes())==f['sha256']
 for s in r['scripts']:assert sha((R/'served-js'/(s['sha256']+'.js')).read_bytes())==s['sha256']
 count=int(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(p.parent/'capture.mp4')],text=True).strip())
 assert count==len(r['frames']),(count,len(r['frames']))
 assert states['rest']['reduce']==(r['reducedMotion']=='reduce')
 for name,date,count in [('tab-tuesday','Tue, Sep 29',2),('blank-focused','Tue, Sep 29',0),('blank-tab','Wed, Sep 30',0),('refresh-focused','Wed, Sep 30',6),('refresh-reverse','Tue, Sep 29',8)]:
  s=states[name];assert (s['focus']['label'] or s['focus']['text'])==f'{count} commits on {date}',(p,name,s['focus'])
  assert f'{count} commits {date}' in s['aria'],(p,name)
 assert not any(line.count('commits')>1 for line in states['shrink-focused']['aria'].splitlines())
 residual=[line for line in states['future-removal-focused']['aria'].splitlines() if line.count('commits')>1]
 assert residual==(['    - button \"0 commits on Sun, Oct 4 0 commits Sun, Oct 4\"'] if r['target']=='candidate' else []),residual
 expectedLast='Show activity level 0' if r['target']=='source' else '10 commits on Sat, Oct 3'
 assert (states['before-last-day-tab']['focus']['label'] or states['before-last-day-tab']['focus']['text'])=='8 commits on Fri, Oct 23'
 assert (states['last-day-tab']['focus']['label'] or states['last-day-tab']['focus']['text'])==expectedLast
 results.append({'target':r['target'],'motion':r['reducedMotion'],'frames':len(r['frames']),'states':len(states)})
assert len(results)==4
print(json.dumps({'archiveIntegrity':'pass','boundedCommonBehavior':'pass','sessions':results,'parity':'See evidence-supplement.json for reproduced failures; integrity passing does not mean parity passing.'},indent=2))
