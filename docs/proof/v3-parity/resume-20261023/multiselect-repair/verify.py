from pathlib import Path
import hashlib,json,subprocess,sys
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['input-lock.json','archive-sha256.json']:
 for f,h in json.loads((r/manifest).read_text()).items():
  p=r/f;assert p.is_file() and not p.is_symlink(),f;assert sha(p)==h,f
identity=json.loads((r/'identity.json').read_text());assert all(x['sameAsHead'] or (x['path']=='lib/src/motion/multi_select.dart' and x.get('sameAsWorkingRepair')) for x in identity['candidateFiles']);assert all(x['sameAsPin'] for x in identity['sourceFiles'])
for b in json.loads((r/'source-input-bindings.json').read_text()):assert sha(r/b['archive'])==b['sha256']
for f in identity['candidateFiles']: assert sha(r/'candidate'/f['path'])==f['sha256']
for f,h in json.loads((r/'exact-hashes.json').read_text())['files'].items(): assert sha(r/f)==h
results=[]
for p in sorted(r.glob('attempt-*/*/results.json')):
 d=json.loads(p.read_text());base=p.parent
 expected=sha(r/('source/source.js' if d['target']=='source' else (('candidate-r'+p.parts[-3].split('-')[1] if p.parts[-3] in ['attempt-1','attempt-2'] else 'candidate')+'/example/build/web/main.dart.js')))
 assert any(x['sha256']==expected for x in d['scripts']),str(p)
 for s in d['scripts']:assert sha(r/'served'/s['sha256'])==s['sha256']
 for s in d['states']:assert sha(base/s['screenshot']['file'])==s['screenshot']['sha256']
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 assert all(e['isTrusted'] or (e['type']=='click' and e['tag']=='FLT-SEMANTICS-PLACEHOLDER') for e in d['inputs'])
 counts={}
 for video in ['capture.mp4','frame-index-replay.mkv']:
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames,width,height','-of','json',str(base/video)]))['streams'][0];counts[video]=int(probe['nb_read_frames'])
 assert counts['frame-index-replay.mkv']==len(d['frames'])
 dec=subprocess.Popen(['ffmpeg','-v','error','-i',str(base/'frame-index-replay.mkv'),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
 for f in d['frames']:
  im=Image.open(base/f['file']).convert('RGB');expected=im.tobytes();chunks=[];left=len(expected)
  while left:
   b=dec.stdout.read(left);assert b,'truncated decode';chunks.append(b);left-=len(b)
  assert hashlib.sha256(b''.join(chunks)).digest()==hashlib.sha256(expected).digest(),str(base/f['file'])
 assert not dec.stdout.read(1);assert dec.wait()==0
 results.append({'run':str(base.relative_to(r)),'originalFrames':len(d['frames']),'decoded':counts,'rgbReplayExact':True,'failures':[x['name'] for x in d['checks'] if not x['pass']]})
for p in (r/'attempt-3').glob('*/results.json'):
 d=json.loads(p.read_text());assert not [c for c in d['checks'] if not c['pass']],str(p)
 states={s['name']:s for s in d['states']}
 for name,q in [('initial-closed-pointer',''),('closed-pointer-typing','zz'),('pointer-remove-alpha',''),('open-pointer-typing','zz')]:
  s=states[name];assert s['focus']['tag'] in ['INPUT','TEXTAREA'],(str(p),name,s['focus'])
  assert s['fixture']['open'] is True and s['fixture']['query']==q
  assert any(f['value']==q for f in s['fields'])
  assert (s['popup'] if d['target']=='source' else 'Options' in s['aria'])
  expectedCalls=1 if name.startswith('initial-') or name.startswith('closed-') else 2
  assert len(s['fixture']['calls'])==expectedCalls
 assert states['closed-pointer-escape']['fixture']['open'] is False
 assert states['outside-dismiss']['fixture']['open'] is False
 assert states['disabled-pointer']['fixture']['calls']==states['open-pointer-query-cleared']['fixture']['calls']
 assert sum(e['type']=='input' and e['isTrusted'] for e in d['inputs'])>=6
 assert sum(e['type']=='pointerdown' and e['isTrusted'] for e in d['inputs']) == (8 if d['owner']=='reject' else 7)
assert len(list((r/'attempt-3').glob('*/results.json')))==8
for p in r.glob('attempt-*/*/*.png'):
 with Image.open(p) as im: im.verify()
print(json.dumps({'verified':True,'runs':results},indent=2))
