from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,base in [('archive-sha256.json',r),('supplemental-assets.json',r/'inputs'),('build-manifest.json',r/'gallery-web')]:
 for f,h in json.loads((r/name).read_text()).items():
  p=base/f;assert p.is_file() and not p.is_symlink(),p;assert sha(p)==h,p
lock=json.loads((r/'input-lock.json').read_text())
for f,h in lock['inputs'].items():assert sha(r/'inputs'/f)==h,f
for f,h in lock['six'].items():assert sha(r/'inputs'/f)==h,f
for f,v in json.loads((r/'served-build.json').read_text()).items():assert v['sha256']==sha(r/'gallery-web'/f) and v['matchesBuild']
runs=[]
paths=sorted(r.glob('*/*/results.json'));assert len(paths)==14,len(paths)
expected_failures=json.loads((r/'expected-failures.json').read_text())
for p in paths:
 d=json.loads(p.read_text());base=p.parent;rel=str(base.relative_to(r))
 for s in d['scripts']:assert sha(r/'served'/s['sha256'])==s['sha256']
 assert any(s['sha256']==sha(r/'gallery-web/main.dart.js') for s in d['scripts'])
 for s in d['states']:
  assert sha(base/s['screenshot']['file'])==s['screenshot']['sha256']
  assert s['reduce']==(d['reducedMotion']=='reduce')
  assert s['probe']['disableAnimations']==s['reduce']==s['probe']['platformDisableAnimations']
  assert s['probe']['motionOverride'] is None
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 assert len(list((base/'original-frames').glob('*.png')))==len(d['frames'])
 assert all(e['isTrusted'] or (e['type']=='click' and e['tag']=='FLT-SEMANTICS-PLACEHOLDER') for e in d['inputs'])
 assert not d['errors']
 counts={}
 for video in ['capture.mp4','frame-index-replay.mkv']:
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames','-of','json',str(base/video)]))['streams'][0];counts[video]=int(probe['nb_read_frames'])
 assert counts['frame-index-replay.mkv']==len(d['frames'])
 dec=subprocess.Popen(['ffmpeg','-v','error','-i',str(base/'frame-index-replay.mkv'),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
 for f in d['frames']:
  expected=Image.open(base/f['file']).convert('RGB').tobytes();data=b''
  while len(data)<len(expected):
   chunk=dec.stdout.read(len(expected)-len(data));assert chunk;data+=chunk
  assert data==expected,str(base/f['file'])
 assert not dec.stdout.read(1);assert dec.wait()==0
 failures=[c['name'] for c in d['checks'] if not c['pass']];assert failures==expected_failures[rel],(rel,failures)
 states={s['name']:s for s in d['states']}
 if d['target']=='collapsible':
  assert 'Keep extra information' not in states['close-keyboard']['aria']
  assert 'Keep extra information' in states['reopen-keyboard']['aria']
 if rel.startswith('scheduler-4/'):
  assert states['apply-focused']['focus']['text']=='Apply\nApply'
  assert states['apply-disabled']['focus']['role']=='checkbox'
  assert states['apply-disabled']['aria']==states['disabled-enter']['aria']
  assert states['apply-keyboard']['aria'].split('text: Saturday')[1].split('text: Sunday')[0].count('button "Remove Remove time range"')==2
  assert states['cancel-outside']['aria'].split('text: Sunday')[1].count('button "Remove Remove time range"')==1
 runs.append({'run':rel,'originalFrames':len(d['frames']),'decoded':counts,'rgbReplayExact':True,'checks':len(d['checks']),'preservedFailures':failures})
print(json.dumps({'archiveVerified':True,'behaviorAllPassed':False,'runs':runs},indent=2))
