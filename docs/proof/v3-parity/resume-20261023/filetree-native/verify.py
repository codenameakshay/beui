from pathlib import Path
import hashlib,json,subprocess,sys
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['input-lock.json','archive-sha256.json']:
 for f,h in json.loads((r/manifest).read_text()).items():
  p=r/f;assert p.is_file() and not p.is_symlink(),f;assert sha(p)==h,f
for b in json.loads((r/'source-input-bindings.json').read_text()):assert sha(r/b['archive'])==b['sha256']
import tarfile
identity=json.loads((r/'identity.json').read_text())
with tarfile.open(r/'candidate-baseline.tar') as t:
 assert hashlib.sha256(t.extractfile('lib/src/motion/file_tree.dart').read()).hexdigest()==identity['candidateFileTreeSha256']
assert sha(r/'candidate-inputs/lib/src/motion/file_tree.dart')==identity['candidateFileTreeSha256']
assert any(x['sha256']==identity['sourceFileTreeSha256'] for x in json.loads((r/'source-input-bindings.json').read_text()))
assert len(json.loads((r/'source-pin-checks.json').read_text()))==4
assert json.loads(subprocess.check_output([sys.executable,str(r/'analyze.py')]))==json.loads((r/'behavior-checks.json').read_text())
results=[]
for p in sorted(r.glob('attempt-*/*/results.json')):
 d=json.loads(p.read_text());base=p.parent
 expected=sha(r/('source/source.js' if d['target']=='source' else ('candidate-build-attempt1/main.dart.js' if 'attempt-1' in str(p) else 'candidate-build/main.dart.js')))
 assert any(x['sha256']==expected for x in d['scripts']),str(p)
 for s in d['scripts']:assert sha(r/'served'/s['sha256'])==s['sha256']
 for s in d['states']:assert sha(base/s['screenshot']['file'])==s['screenshot']['sha256']
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 assert all(e['isTrusted'] for e in d['inputs'])
 failures=[x['name'] for x in d['checks'] if not x['pass']]
 assert failures==(['sequence completed'] if 'attempt-1' in str(p) and d['target']=='candidate' else [])
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
print(json.dumps({'verified':True,'runs':results},indent=2))
