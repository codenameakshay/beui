from pathlib import Path
import hashlib,json,subprocess,tarfile
R=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
seal=json.loads((R/'archive-sha256.json').read_text())
for name,h in seal.items():
 p=R/name
 assert p.is_file() and not p.is_symlink() and sha(p)==h,name
videos=frames=0
for p in R.rglob('results.json'):
 d=json.loads(p.read_text())
 if not isinstance(d,dict) or 'frames' not in d:continue
 for f in d['frames']:assert sha(p.parent/f['file'])==f['sha256']
 for s in d['states']:assert sha(p.parent/s['screenshot']['file'])==s['screenshot']['sha256']
 if (p.parent/'capture.mp4').exists():
  count=int(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(p.parent/'capture.mp4')],text=True).strip())
  assert count==len(d['frames']);videos+=1;frames+=count
for folder in ['lifecycle-worker','lifecycle-parent']:
 paths=list((R/folder/'native-final').glob('*/results.json'));assert len(paths)==4
 for p in paths:
  d=json.loads(p.read_text());s={x['name']:x for x in d['states']};candidate=d['target']=='candidate'
  focus=lambda n:s[n]['focus']['label'] or s[n]['focus']['text']
  prefix='Filter' if candidate else 'Show'
  assert focus('last-day-tab')==prefix+' activity level 0'
  assert focus('legend-next-tab')==prefix+' activity level 1'
  assert s['future-removal-focused']['focus']['tag']==('FLUTTER-VIEW' if candidate else 'BODY')
  assert focus('future-removal-next')==prefix+' activity level 0'
  assert focus('reverse-next')=='0 commits on Mon, Oct 19'
  assert focus('external-focused')=='date' and focus('external-reverse')=='shrink'
  assert focus('new-anchor')=='0 commits on Mon, Oct 5'
  assert focus('new-anchor-locked')=='2 commits on Tue, Oct 6'
  events=s['future-removal-next']['inputs'][len(s['future-removal-focused']['inputs']):]
  assert not any(e['type']=='focusin' and 'commits on' in(e.get('label') or e.get('text') or '') for e in events)
  assert all(e['isTrusted'] or(e['type']=='click' and e.get('x')==0 and e.get('y')==0) for e in d['inputs'])
  assert not d['errors'] and all(c['pass'] for c in d['checks'])
  assert s['rest']['reduce']==(d['reducedMotion']=='reduce')
  for script in d['scripts']:
   assert sha(R/folder/'served-js'/(script['sha256']+'.js'))==script['sha256']
custom=json.loads((R/'lifecycle-worker/custom-native/results.json').read_text());assert len(custom)==4
for run in custom:assert all(run['checks'].values())
for name in ['build','custom-build']:
 with tarfile.open(R/'lifecycle-worker'/(name+'-inputs.tar.gz')) as t:
  chart=t.extractfile('lib/src/charts/heat_calendar.dart').read()
  assert hashlib.sha256(chart).hexdigest()=='939a3ea71a36b7e50358cdc38576f2f2da2ba68f91c0acdddaae4286dab5e548'
print(json.dumps({'hashes':len(seal),'decodedVideos':videos,'originalFrames':frames,'finalDefaultSessions':8,'customSessions':4,'status':'PASS','limits':['Selection readout also requires visual inspection','No pixel or native60 certification']}))
