from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['input-lock.json','archive-sha256.json']:
 for f,h in json.loads((r/manifest).read_text()).items():
  p=r/f
  assert p.is_file() and not p.is_symlink(),f
  assert sha(p)==h,f
identity=json.loads((r/'identity.json').read_text())
assert all(x['sameAsPin'] for x in identity['sourceFiles'])
assert all(x['buildCopyMatches'] for x in identity['candidateFiles'])
for b in json.loads((r/'source-input-bindings.json').read_text()):assert sha(r/b['archive'])==b['sha256']
results=[]
for p in sorted(r.glob('attempt-*/*/results.json')):
 d=json.loads(p.read_text());base=p.parent
 expected=sha(r/('source/source.js' if d['target']=='source' else 'candidate/example/build/web/main.dart.js'))
 assert any(x['sha256']==expected for x in d['scripts']),str(p)
 for s in d['scripts']:assert sha(r/'served'/s['sha256'])==s['sha256']
 for s in d['states']:assert sha(base/s['screenshot']['file'])==s['screenshot']['sha256']
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 assert all(e['isTrusted'] for e in d['inputs'] if e['type'] in ['keydown','keyup'])
 counts={}
 if not d['frames']:
  results.append({'run':str(base.relative_to(r)),'originalFrames':0,'failures':[x['name'] for x in d['checks'] if not x['pass']]})
  continue
 for video in ['capture.mp4','frame-index-replay.mkv']:
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames','-of','json',str(base/video)]))['streams'][0]
  counts[video]=int(probe['nb_read_frames'])
 assert counts['frame-index-replay.mkv']==len(d['frames'])
 dec=subprocess.Popen(['ffmpeg','-v','error','-i',str(base/'frame-index-replay.mkv'),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
 for f in d['frames']:
  expected=Image.open(base/f['file']).convert('RGB').tobytes();chunks=[];left=len(expected)
  while left:
   b=dec.stdout.read(left);assert b,'truncated decode';chunks.append(b);left-=len(b)
  assert hashlib.sha256(b''.join(chunks)).digest()==hashlib.sha256(expected).digest(),str(base/f['file'])
 assert not dec.stdout.read(1);assert dec.wait()==0
 results.append({'run':str(base.relative_to(r)),'originalFrames':len(d['frames']),'decoded':counts,'rgbReplayExact':True,'timestampVideoFrameLoss':len(d['frames'])-counts['capture.mp4'],'failures':[x['name'] for x in d['checks'] if not x['pass']]})
print(json.dumps({'verified':True,'runs':results},indent=2))
