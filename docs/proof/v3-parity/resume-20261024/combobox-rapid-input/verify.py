"""Portable evidence integrity; deliberately not a behavioral acceptance claim."""
from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((r/'archive-sha256.json').read_text())
for f,h in m.items(): assert sha(r/f)==h,f
for prefix in ['final','final2']:
 for f,h in json.loads((r/(prefix+'-inputs.json')).read_text()).items():assert sha(r/(prefix+'-inputs')/f)==h,f
 for f,h in json.loads((r/(prefix+'-build-manifest.json')).read_text()).items():assert sha(r/(prefix+'-web')/f)==h,f
assert json.loads((r/'served-final2.json').read_text())==json.loads((r/'final2-build-manifest.json').read_text())
expected=json.loads((r/'expected-capture-failures.json').read_text());contexts=frames=0
for f,failures in expected.items():
 p=r/f;d=json.loads(p.read_text());contexts+=1
 assert [c['name'] for c in d['checks'] if not c['pass']]==failures,f
 for e in d['inputs']:
  assert e['isTrusted'] or (e['type']=='click' and e['tag']=='FLT-SEMANTICS-PLACEHOLDER'),f
 for state in d['states']:
  assert sha(p.parent/state['screenshot']['file'])==state['screenshot']['sha256'],f
  Image.open(p.parent/state['screenshot']['file']).verify()
  assert state['reduce']==(d['reducedMotion']=='reduce'),f
  if 'probe' in state:
   assert state['probe']['disableAnimations']==state['reduce'],f
   assert state['probe']['platformDisableAnimations']==state['reduce'],f
 for frame in d['frames']:
  assert sha(p.parent/frame['file'])==frame['sha256'],f
  Image.open(p.parent/frame['file']).verify();frames+=1
 replay=p.parent/'frame-index-replay.mkv'
 if replay.exists():
  # Each decoded lossless RGB frame must equal the original PNG pixels.
  dec=subprocess.Popen(['ffmpeg','-v','error','-i',str(replay),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
  for frame in d['frames']:
   rgb=Image.open(p.parent/frame['file']).convert('RGB').tobytes();data=b''
   while len(data)<len(rgb):
    chunk=dec.stdout.read(len(rgb)-len(data))
    assert chunk,f
    data+=chunk
   assert data==rgb,f
  assert not dec.stdout.read(1),f
  assert dec.wait()==0,f
 if p.parts[-3].startswith('final2-'):
  for script in d['scripts']:
   if script['url'].split('?')[0].endswith('/main.dart.js'):assert script['sha256']==sha(r/'final2-web/main.dart.js'),f
print(json.dumps({'integrity':'pass','contexts':contexts,'originalFrames':frames,'behavioralAcceptance':'separate; initial editor-delivery failure remains disclosed'}))
