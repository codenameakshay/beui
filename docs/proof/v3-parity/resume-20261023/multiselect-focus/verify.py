from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['input-lock.json','archive-sha256.json']:
 for name,h in json.loads((r/manifest).read_text()).items():
  p=r/name;assert p.is_file() and not p.is_symlink(),name;assert sha(p)==h,name
for b in json.loads((r/'source-input-bindings.json').read_text()):assert sha(r/b['archive'])==b['sha256']
for f,h in json.loads((r/'exact-hashes.json').read_text())['files'].items():assert sha(r/f)==h
runs=[]
for p in sorted([*r.glob('attempt-*/*/results.json'), *r.glob('final/*/results.json'), *r.glob('source-recheck/*/results.json')]):
 d=json.loads(p.read_text());base=p.parent
 for s in d['scripts']:assert sha(r/'served'/s['sha256'])==s['sha256']
 for s in d['states']:assert sha(base/s['screenshot']['file'])==s['screenshot']['sha256']
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 assert all(e['isTrusted'] or (e['type']=='click' and e['tag']=='FLT-SEMANTICS-PLACEHOLDER') for e in d['inputs'])
 replay='frame-index-replay-complete.mkv' if (base/'frame-index-replay-complete.mkv').exists() else 'frame-index-replay.mkv'
 counts={}
 for video in list(dict.fromkeys(['capture.mp4','frame-index-replay.mkv',replay])):
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames','-of','json',str(base/video)]))['streams'][0];counts[video]=int(probe['nb_read_frames'])
 assert counts[replay]==len(d['frames'])
 dec=subprocess.Popen(['ffmpeg','-v','error','-i',str(base/replay),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
 for f in d['frames']:
  expected=Image.open(base/f['file']).convert('RGB').tobytes();data=b''
  while len(data)<len(expected):
   chunk=dec.stdout.read(len(expected)-len(data));assert chunk;data+=chunk
  assert data==expected,str(base/f['file'])
 assert not dec.stdout.read(1);assert dec.wait()==0
 runs.append({'run':str(base.relative_to(r)),'originalFrames':len(d['frames']),'decoded':counts,'rgbReplayExact':True,'failures':[c['name'] for c in d['checks'] if not c['pass']]})
recheck=json.loads((r/'source-recheck/source-no-preference-accept/results.json').read_text());assert all(c['pass'] for c in recheck['checks'])
final=r/'final'
assert len(list(final.glob('*/results.json')))==8
for p in final.glob('*/results.json'):
 d=json.loads(p.read_text()); failures=[c['name'] for c in d['checks'] if not c['pass']]
 assert not failures or (p.parent.name=='source-no-preference-accept' and failures==['initial-closed-pointer visible chips']),(str(p),failures)
 states={s['name']:s for s in d['states']}
 expected=sha(r/('source/source.js' if d['target']=='source' else 'candidate/example/build/web/main.dart.js'));assert any(s['sha256']==expected for s in d['scripts'])
 for name,q in [('closed-pointer-typing','zz'),('closed-pointer-escape-typing','xy'),('direct-retyping','xy')]:
  s=states[name];assert s['focus']['tag']=='INPUT' and s['focus']['value']==q,(str(p),name,s['focus']);assert s['fixture']['query']==q and s['fixture']['open'];assert s['popup'] if d['target']=='source' else 'Options' in s['aria']
 for name in ['closed-pointer-escape','direct-escape']:
  s=states[name];assert not s['fixture']['open'] and s['focus']['tag']=='INPUT'
 for name in ['chip-tab','direct-tab']:
  assert states[name]['focus']['tag']=='INPUT' and states[name]['focus']['label']=='External field',(str(p),name)
 for name in ['chip-shift-tab','direct-shift-tab']:
  assert states[name]['focus']['tag']=='INPUT' and states[name]['focus'].get('value')==('' if d['target']=='source' else 'xy'),(str(p),name)
 before=states['closed-pointer-typing']['fixture'];after=states['closed-pointer-escape']['fixture']
 assert after['opens'][len(before['opens']):]==[False]
 assert after['queries'][len(before['queries']):]==['']
 assert states['later-external-click']['focus']['label']=='External field'
 assert states['external-typing']['focus']['value']=='external'
 assert states['disposed']['fixture']['alive'] is False
 for name in ['controlled-rejection-chip','controlled-rejection-typing']:
  assert not states[name]['fixture']['open'] and any(f['value']=='kept' for f in states[name]['fields'])
for p in sorted(r.glob('attempt-*/*/partial.json')):
 d=json.loads(p.read_text());base=p.parent
 dec=subprocess.Popen(['ffmpeg','-v','error','-i',str(base/'frame-index-replay.mkv'),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
 for f in d['frames']:
  assert sha(base/f['file'])==f['sha256'];expected=Image.open(base/f['file']).convert('RGB').tobytes();data=b''
  while len(data)<len(expected):
   chunk=dec.stdout.read(len(expected)-len(data));assert chunk;data+=chunk
  assert data==expected
 assert not dec.stdout.read(1);assert dec.wait()==0
 runs.append({'run':str(base.relative_to(r)),'partial':True,'originalFrames':len(d['frames']),'rgbReplayExact':True,'timingAvailable':False})
print(json.dumps({'verified':True,'runs':runs},indent=2))
