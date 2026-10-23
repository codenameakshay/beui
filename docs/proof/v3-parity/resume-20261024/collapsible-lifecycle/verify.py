from pathlib import Path
import json,hashlib,subprocess
from PIL import Image
root=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['archive-sha256.json','build-lock.json']:
 for name,h in json.loads((root/manifest).read_text()).items():
  p=root/name;assert p.is_file() and not p.is_symlink(),name;assert sha(p)==h,name
bindings=json.loads((root/'source-bindings.json').read_text())
assert bindings['pin']=='a76e57c9bbc2837e96420b2610e9c82a3271bb05'
for x in bindings['inputs']:
 assert sha(root/x['file'])==x['sha256']
 if 'gitPath' in x:assert x['gitSha256']==x['sha256']
report=[]
for result in sorted(root.glob('*/*/results.json')):
 r=json.loads(result.read_text());folder=result.parent
 for s in r['scripts']:
  assert sha(root/'served'/s['sha256'])==s['sha256']
 bundle='source/source.js' if r['target']=='source' else ('after-build/main.dart.js' if r['attempt'] in ['final','final2'] else 'before-build/main.dart.js')
 assert sha(root/bundle) in [s['sha256'] for s in r['scripts']],str(result)
 for s in r['states']:assert sha(folder/s['screenshot']['file'])==s['screenshot']['sha256']
 for f in r['frames']:assert sha(folder/f['file'])==f['sha256']
 frames=r['frames'];w,h=Image.open(folder/frames[0]['file']).size
 p=subprocess.Popen(['ffmpeg','-v','error','-i',str(folder/'frame-index-replay.mkv'),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
 for f in frames:
  data=p.stdout.read(w*h*3);assert data==Image.open(folder/f['file']).convert('RGB').tobytes(),f['file']
 assert p.stdout.read()==b'';assert p.wait()==0
 count=int(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(folder/'capture.mp4')]))
 if r['attempt']=='final2':
  assert len(r['checks'])==24 and all(x['pass'] for x in r['checks']),str(result)
  states={x['name']:x for x in r['states']};close=states['external-close'];assert close['fixture']['calls']==[] and close['fixture']['open']==False
  assert abs(close['fixture']['height']-(1 if r['target']=='source' else 0))<.02
  assert 'textbox "Inside"' not in close['aria'];assert states['next-tab']['focus']['label'].endswith('Outside')
  for key in ['outside-close','later-outside']:assert states[key]['focus']['label'].endswith('Outside')
  assert states['rejected']['fixture']['calls']==[False] and states['rejected']['fixture']['open']
  assert states['uncontrolled-close']['fixture']['calls']==[False]
  assert not states['disposed']['fixture']['alive']
  assert not r['errors']
  assert all(x['isTrusted'] or (x['type']=='click' and x['tag']=='FLT-SEMANTICS-PLACEHOLDER') for x in r['inputs'])
 if r['attempt']=='before-retry' and r['target']=='candidate':assert not next(c['pass'] for c in r['checks'] if c['name']=='external close trigger focus')
 report.append({'run':str(result.relative_to(root)),'frames':len(frames),'timestampFrames':count,'checks':len(r['checks']),'failures':[c['name'] for c in r['checks'] if not c['pass']]})
assert len([r for r in report if r['run'].startswith('final2/')])==4
print(json.dumps({'runs':report,'originalFrames':sum(r['frames'] for r in report),'status':'passed'},indent=2))
