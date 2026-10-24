from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,base in [('input-lock.json',r),('archive-sha256.json',r),('production-manifest.json',r/'inputs'),('build-manifest.json',r/'gallery-web')]:
 for f,h in json.loads((r/name).read_text()).items():
  p=base/f;assert p.is_file() and not p.is_symlink(),p;assert sha(p)==h,p
expected={'sortable_list':'083f0b5b6a479d249c14050713186b23418ce449710d4e7f03f715a834994c98','file_tree':'06da09b01f4636df4c14d35f8ad0ee3863d7ab9921bc0e028c2d4d7f7fcd6105','multi_select':'b58e5bfb3c254357da25ae3af77ff22a0b5526160d77e8c3ec2e7496e87c95bb'}
for n,h in expected.items():assert sha(r/'inputs/lib/src/motion'/f'{n}.dart')==h
runs=[]
paths=sorted(r.glob('*/*/results.json'));assert len(paths)==16,len(paths)
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
 if d['target']=='sortable-stack':
  assert states['accepted-move']['focus']['tag']=='BODY'
  assert states['unrecovered-second-key']['focus']['tag']=='BODY'
 if d['target']=='multi-select':
  for name,q in ([('typing','zz'),('retyping','xy')] if rel.startswith('no-match/') else [('typing','pro'),('retyping','res')]):assert states[name]['focus']['tag']=='INPUT' and states[name]['focus']['value']==q
  assert states['escape']['focus']['value']==''
  if rel.startswith('no-match/'):
   assert 'No options found.' in states['typing']['aria'] and 'No options found.' in states['retyping']['aria']
   assert states['tab']['focus']['text']=='Sortable List' and 'Options' not in states['tab']['aria']
   assert states['shift-tab']['focus']['text']=='Arc Picker'
 runs.append({'run':rel,'originalFrames':len(d['frames']),'decoded':counts,'rgbReplayExact':True,'checks':len(d['checks']),'preservedFailures':failures})
print(json.dumps({'archiveVerified':True,'behaviorAllPassed':False,'runs':runs},indent=2))
