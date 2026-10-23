#!/usr/bin/env python3
"""Offline evidence integrity and independent behavioral audit. Python 3 + ffmpeg."""
import hashlib,json,pathlib,subprocess,sys
P=pathlib.Path(__file__).resolve().parent
H=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def frames(args):
 out=subprocess.check_output(['ffmpeg','-v','error',*args,'-pix_fmt','rgb24','-f','framemd5','-'],text=True)
 return [x.split(',')[-1].strip() for x in out.splitlines() if x and not x.startswith('#')]
def verify():
 manifest=json.loads((P/'archive-lock.json').read_text())
 for name,digest in manifest.items():
  assert H(P/name)==digest,name
 for row in json.loads((P/'source-input-lock.json').read_text()):
  assert H(P/row['archive'])==row['sha256'],row['path']
 reports=[]
 for f in sorted((P/'native-recovery-1').glob('*/observations.json')):
  d=json.loads(f.read_text());root=f.parent;candidate=d['target']=='candidate'
  bundle=P/('candidate-build/main.dart.js' if candidate else 'source-recovery-build/source.js')
  assert d['scripts'] and all(x['sha256']==H(bundle) for x in d['scripts'])
  assert d['reduce']==(d['reducedMotion']=='reduce')
  assert not any('error' in x for x in d['logs'])
  untrusted=[x for x in d['inputs'] if not x['trusted']]
  assert all(x['type']=='click' and x['tag']=='FLT-SEMANTICS-PLACEHOLDER' for x in untrusted)
  assert len(untrusted)==int(candidate)
  for frame in d['frames']:assert H(root/frame['file'])==frame['sha256']
  png=frames(['-framerate','25','-i',str(root/'frames/%06d.png')])
  replay=frames(['-i',str(root/'frame-index-replay.mkv')])
  assert png==replay and len(png)==len(d['frames'])
  checks={}
  for name,word in [('escape','Banana'),('select','Banana'),('escape-empty','Nothing found')]:
   a=next(x for x in d['actions'] if x['name']==name)
   window=[s for s in d['samples'] if a['time']+10<s['time']<a['time']+100 and s['panel']]
   checks[name]=bool(window) and all(word in s.get('text','') and 'Apple' not in s.get('text','') and 'Cherry' not in s.get('text','') for s in window)
   if candidate:
    expected='Banana' if name=='select' else ''
    checks[name+'-input']=any(s.get('input')==expected for s in window)
  last=d['samples'][-1]
  checks['reopen-fresh-query']=last.get('input')=='apl' and last['panel'] and 'Apple' in last.get('text','') and 'Banana' not in last.get('text','')
  reports.append({'run':root.name,'frames':len(png),'servedSHA256':H(bundle),'checks':checks})
 assert len(reports)==4
 assert 'All tests passed!' in (P/'test-recovery.log').read_text()
 assert 'No issues found!' in (P/'analyze-recovery.log').read_text()
 return {'integrity':'pass','acceptance':all(all(r['checks'].values()) for r in reports),'native':reports,'controlledOwnership':'21-test focused widget suite; no controlled native fixture','limits':['Reduced-motion native mid-exit reopen fails in recovery capture.','Source no-results exit retains selected Banana input and Fresh label; candidate clears input and hides empty group.','RGB replay is a synthetic 25fps frame index, not original timing.','No pixel parity, timing/performance, physical device, screen reader, cross-browser, full suite, golden, CI or release claim.']}
if __name__=='__main__':
 try:print(json.dumps(verify(),indent=2))
 except Exception as e:print(str(e),file=sys.stderr);sys.exit(1)
