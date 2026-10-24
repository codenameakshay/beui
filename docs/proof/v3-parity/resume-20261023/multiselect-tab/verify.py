from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['input-lock.json','archive-sha256.json']:
 for name,h in json.loads((r/manifest).read_text()).items():
  p=r/name;assert p.is_file() and not p.is_symlink(),name;assert sha(p)==h,name
for manifest in ['source-input-bindings.json','source-build-bindings.json']:
 for b in json.loads((r/manifest).read_text()):assert sha(r/b['archive'])==b['sha256']
for f,h in json.loads((r/'exact-hashes.json').read_text())['files'].items():assert sha(r/f)==h
assert sha(r/'inputs/before.dart')=='dba8218b7d836f7a7d48994417a7573ca3682ef2daf5f62a27058aa49beafa12'
runs=[]
paths=sorted(r.glob('final/*/results.json'))
assert len(paths)==8
for p in paths:
 d=json.loads(p.read_text());base=p.parent
 for s in d['scripts']:assert sha(r/'served'/s['sha256'])==s['sha256']
 for s in d['states']:assert sha(base/s['screenshot']['file'])==s['screenshot']['sha256']
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 assert len(list((base/'original-frames').glob('*.png')))==len(d['frames'])
 assert all(e['isTrusted'] or (e['type']=='click' and e['tag']=='FLT-SEMANTICS-PLACEHOLDER') for e in d['inputs'])
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
 failures=[c['name'] for c in d['checks'] if not c['pass']];assert not failures,(str(p),failures)
 states={s['name']:s for s in d['states']}
 expected=sha(r/('source/source.js' if d['target']=='source' else 'candidate/example/build/web/main.dart.js'));assert any(s['sha256']==expected for s in d['scripts'])
 for name,q in [('closed-pointer-typing','zz'),('closed-pointer-escape-typing','xy'),('direct-retyping','xy')]:
  s=states[name];assert s['focus']['tag']=='INPUT' and s['focus']['value']==q,(str(p),name,s['focus']);assert s['fixture']['query']==q and s['fixture']['open'];assert s['popup'] if d['target']=='source' else 'Options' in s['aria']
 for name in ['closed-pointer-escape','direct-escape']:
  s=states[name];assert not s['fixture']['open'] and s['focus']['tag']=='INPUT'
 for previous,tab,back in [('closed-pointer-escape-typing','chip-tab','chip-shift-tab'),('direct-retyping','direct-tab','direct-shift-tab')]:
  a,b,c=[states[n] for n in [previous,tab,back]]
  assert b['focus']['tag']=='INPUT' and b['focus']['label']=='External field',(str(p),tab)
  assert not b['fixture']['open'] and b['fixture']['query']==''
  assert b['fixture']['opens'][len(a['fixture']['opens']):]==[False]
  assert b['fixture']['queries'][len(a['fixture']['queries']):]==['']
  assert c['focus']['tag']=='INPUT' and c['focus']['value']=='' and c['focus']['label']!='External field'
  assert c['fixture']['open'] and c['fixture']['query']==''
  assert c['fixture']['opens'][len(b['fixture']['opens']):]==[True]
  assert c['fixture']['queries']==b['fixture']['queries']
  assert a['fixture']['calls']==b['fixture']['calls']==c['fixture']['calls']
  assert a['fixture']['value']==b['fixture']['value']==c['fixture']['value']
 a,b,c=[states[n] for n in ['reject-open-focused','reject-open-tab','reject-open-return']]
 assert b['focus']['label']=='External field' and b['fixture']['open'] and b['fixture']['query']=='kept'
 assert b['fixture']['opens'][len(a['fixture']['opens']):]==[False]
 assert b['fixture']['queries'][len(a['fixture']['queries']):]==['']
 assert c['focus']['value']=='kept' and c['fixture']['open']
 assert c['fixture']['opens'][len(b['fixture']['opens']):]==[True]
 assert a['fixture']['calls']==b['fixture']['calls']==c['fixture']['calls']==[]
 assert states['later-external-click']['focus']['label']=='External field'
 assert states['external-typing']['focus']['value']=='external'
 assert states['disposed']['fixture']['alive'] is False
 for name in ['controlled-rejection-chip','controlled-rejection-typing']:
  assert not states[name]['fixture']['open'] and any(f['value']=='kept' for f in states[name]['fields'])
 runs.append({'run':str(base.relative_to(r)),'originalFrames':len(d['frames']),'decoded':counts,'rgbReplayExact':True,'checks':len(d['checks']),'failures':failures})
print(json.dumps({'verified':True,'runs':runs},indent=2))
