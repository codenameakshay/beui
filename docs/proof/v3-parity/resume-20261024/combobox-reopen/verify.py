#!/usr/bin/env python3
import hashlib,json,pathlib,subprocess
P=pathlib.Path(__file__).resolve().parent
H=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def rgb(args):
 text=subprocess.check_output(['ffmpeg','-v','error',*args,'-pix_fmt','rgb24','-f','framemd5','-'],text=True)
 return [s.split(',')[-1].strip() for s in text.splitlines() if s and not s.startswith('#')]
def verify():
 for name,digest in json.loads((P/'archive-lock.json').read_text()).items(): assert H(P/name)==digest,name
 for row in json.loads((P/'source-input-lock.json').read_text()): assert H(P/row['archive'])==row['sha256']
 reports=[]
 for phase in ['baseline','final']:
  for f in sorted((P/phase).glob('*/observations.json')):
   d=json.loads(f.read_text());candidate=d['target']=='candidate'
   bundle=P/('source-build/source.js' if not candidate else ('baseline-build/main.dart.js' if phase=='baseline' else 'candidate-build/main.dart.js'))
   assert d['scripts'] and all(r['sha256']==H(bundle) for r in d['scripts'])
   assert d['reduce']==(d['reducedMotion']=='reduce')
   untrusted=[r for r in d['inputs'] if not r['trusted']]
   assert len(untrusted)==int(candidate)
   assert all(r['type']=='click' and r['tag']=='FLT-SEMANTICS-PLACEHOLDER' for r in untrusted)
   assert not any('error' in r for r in d['logs'])
   for frame in d['frames']: assert H(f.parent/frame['file'])==frame['sha256']
   original=rgb(['-framerate','25','-i',str(f.parent/'frames/%06d.png')]);replay=rgb(['-i',str(f.parent/'frame-index-replay.mkv')]);assert original==replay and len(original)==len(d['frames'])
   s=d['samples'][-1]
   passed=s.get('input')=='apl' and s['panel'] and 'Apple' in s.get('text','') and 'Banana' not in s.get('text','') and s['rect']['height']>0
   reports.append({'phase':phase,'run':f.parent.name,'reopen':passed,'frames':len(original),'servedSHA256':H(bundle)})
 assert len(reports)==8
 assert any(r['phase']=='baseline' and r['run']=='candidate-reduce' and not r['reopen'] for r in reports)
 assert 'All tests passed!' in (P/'test-final.log').read_text()
 assert 'No issues found!' in (P/'analyze-final.log').read_text()
 return {'integrity':'pass','reopenAcceptance':all(r['reopen'] for r in reports if r['phase']=='final'),'reports':reports,'controlledOwnership':'Widget only; existing four acceptance/rejection combinations pass. Native fixture uncontrolled.','limits':'No failing-first widget reproduction. No full parity, pixel parity, timing, performance, physical device, screen reader, CI or release claim.'}
if __name__=='__main__': print(json.dumps(verify(),indent=2))
