"""Offline archive integrity and bounded observed behavior; never a parity certificate."""
from pathlib import Path
import json,hashlib,tarfile,subprocess,sys
r=Path(__file__).resolve().parent
read=lambda p:json.loads((r/p).read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
fail=[];count=0
def check(name,ok):
 global count
 count+=1
 if not ok:fail.append(name)
for name,digest in read('archive-sha256.json').items():check('hash '+name,sha((r/name).read_bytes())==digest)
for name,entries in [('candidate-input-originals.tar.gz',read('candidate-inputs.json')),('source-input-originals.tar.gz',{x['path'].lstrip('/'):x['sha256'] for x in read('source-inputs.json')['inputs']})]:
 with tarfile.open(r/name) as t:
  check(name+' regular files',all(x.isfile() or x.isdir() for x in t.getmembers()))
  for path,digest in entries.items():check(name+'/'+path,sha(t.extractfile(path).read())==digest)
with tarfile.open(r/'served-builds.tar.gz') as t:check('served files regular',all(x.isfile() or x.isdir() for x in t.getmembers()))
check('pinned source inputs',all(x['matchesPinned'] for x in read('pinned-input-check.json')))
snap=read('snapshots.json');sessions=[]
for motion in ['no-preference','reduce']:
 pair={}
 for target in ['source','candidate']:
  folder=f'attempt-2/{target}-{motion}';d=read(folder+'/results.json');states={s['name']:s for s in d['states']};pair[target]=states
  check(folder+' capture completed',len(states)==23 and all(c['pass'] for c in d['checks']))
  for name,s in states.items():
   check(folder+'/'+name+' inputs',s['fixture']['snapshot']==snap[s['fixture']['state']])
   check(folder+'/'+name+' motion',s['reduce']==s['fixture']['disableAnimations']==(motion=='reduce'))
   check(folder+'/'+name+' screenshot',sha((r/folder/s['screenshot']['file']).read_bytes())==s['screenshot']['sha256'])
  for f in d['frames']:check(folder+'/'+f['file'],sha((r/folder/f['file']).read_bytes())==f['sha256'])
  for js in d['scripts']:check('served JS '+js['sha256'],sha((r/'served-js'/(js['sha256']+'.js')).read_bytes())==js['sha256'])
  times=[f['metadata']['timestamp'] for f in d['frames']];check(folder+' frame timestamps',all(b>a for a,b in zip(times,times[1:])))
  n=int(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(r/folder/'capture.mp4')],text=True));check(folder+' video frames',n==len(times))
  check(folder+' trusted input',all(e['isTrusted'] or (e['type']=='click' and e.get('x')==0 and e.get('y')==0) for e in d['inputs']))
  check(folder+' native input coverage',all(any(e['type']==kind and e['isTrusted'] for e in d['inputs']) for kind in ['pointerdown','pointerup','keydown','keyup']))
  for name in ['before-missing','before-year-replace','before-year-remove','before-empty']:check(folder+'/'+name+' focus tracked',states[name]['identity']['sameFocused'])
  check(folder+' missing month retains focused element',states['missing-focused']['identity']['sameFocused'])
  check(folder+' removed row disconnects',not states['year-removed']['identity']['connected'])
  check(folder+' empty disconnects',not states['empty-focused']['identity']['connected'])
  check(folder+' old removed identity does not resurrect',not states['removed-year-reinserted']['identity']['connected'])
  for name,readout in [('hover-march','Mar 2025 +4.0%'),('missing-next','Apr 2025 +0.0%'),('months-reinserted','Apr 2025 −4.0%'),('months-reverse','Mar 2025 +4.0%')]:check(folder+'/'+name+' actual readout',readout in states[name]['aria'])
  for name,month in [('missing-next','Apr'),('months-reverse','Mar')]:check(folder+'/'+name+' native focus',month in (states[name]['focus']['label'] or states[name]['focus']['text']))
  expected='Jan' if target=='source' else 'Apr'
  check(folder+' replacement next focus',expected in (states['replacement-next']['focus']['label'] or states['replacement-next']['focus']['text']))
  check(folder+' removal next focus',states['removal-next']['focus']['text']=='initial')
  check(folder+' empty next focus',states['empty-next']['focus']['text']==('initial' if target=='source' else 'replace'))
  sessions.append({'target':target,'motion':motion,'states':len(states),'frames':n})
 for name in pair['source']:check(motion+'/'+name+' paired inputs',pair['source'][name]['fixture']['snapshot']==pair['candidate'][name]['fixture']['snapshot'])
 check(motion+' source replacement removes identity',not pair['source']['year-replaced']['identity']['connected'])
 check(motion+' candidate replacement reuses identity',pair['candidate']['year-replaced']['identity']['sameFocused'])
print(json.dumps({'integrityAndObservedBehavior':'PASS' if not fail else 'FAIL','parity':'NOT CERTIFIED; year replacement identity differs','checks':count,'failures':fail,'sessions':sessions},indent=2));sys.exit(bool(fail))
