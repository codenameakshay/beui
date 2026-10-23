from pathlib import Path
import hashlib,json,subprocess,sys
from PIL import Image
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['input-lock.json','archive-sha256.json']:
 for f,h in json.loads((r/manifest).read_text()).items():
  p=r/f;assert p.is_file() and not p.is_symlink(),f;assert sha(p)==h,f
for manifest in ['source-input-bindings.json','source-controls-input-bindings.json']:
 for b in json.loads((r/manifest).read_text()):assert sha(r/b['archive'])==b['sha256']
import tarfile
identity=json.loads((r/'identity.json').read_text())
assert sha(r/'candidate-inputs/lib/src/motion/file_tree.dart')==identity['candidateFileTreeSha256']
assert sha(r/'candidate-inputs/test/motion/file_tree_test.dart')==identity['testSha256']
assert any(x['sha256']==identity['sourceFileTreeSha256'] for x in json.loads((r/'source-input-bindings.json').read_text()))
assert json.loads(subprocess.check_output([sys.executable,str(r/'analyze.py')]))==json.loads((r/'behavior-checks.json').read_text())
results=[]
for p in sorted(r.glob('attempt-*/*/results.json')):
 d=json.loads(p.read_text());base=p.parent
 controls='attempt-controls' in str(p)
 controlSetupFailure=d['target']=='candidate' and p.parent.parent.name in ['attempt-controls','attempt-controls2']
 build='source' if d['target']=='source' else ('candidate-build-attempt1' if 'attempt-1' in str(p) else 'candidate-build')
 expected=sha(r/build/('controls' if controls else '')/('source.js' if d['target']=='source' else 'main.dart.js'))
 if controlSetupFailure: expected=sha(r/'candidate-build/main.dart.js')
 if p.parent.parent.name=='attempt-controls' and d['target']=='source': expected=sha(r/'source-controls-attempt1/source.js')
 assert any(x['sha256']==expected for x in d['scripts']),str(p)
 for s in d['scripts']:assert sha(r/'served'/s['sha256'])==s['sha256']
 for s in d['states']:assert sha(base/s['screenshot']['file'])==s['screenshot']['sha256']
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 assert all(e['isTrusted'] for e in d['inputs'])
 failures=[x['name'] for x in d['checks'] if not x['pass']]
 expectedFailure=controlSetupFailure or (p.parent.parent.name=='attempt-controls' and d['target']=='source')
 assert failures==(['sequence completed'] if expectedFailure else []),(p,failures)
 if 'attempt-1' in str(p) and d['target']=='candidate':
  assert [s['focus']['text'] for s in d['states'] if s['name'].startswith('disabled-')]==['Leaf','Leaf','Leaf']
 if controls and not expectedFailure:
  assert d['states'][-1]['fixture']['controlCalls']==['Inspect','Pin']
  for state in d['states']:
   if state['name'].startswith('disabled-'):
    assert state['focus']['text']=='Disabled'
    assert state['fixture']['expanded']==['parent','folder']
    assert state['fixture']['calls']==['leaf']
    assert len(state['fixture']['expCalls'])==2
    row=next(x for x in state['rows'] if x['text']=='Disabled')
    assert row['expanded']=='false'
    if d['target']=='candidate': assert 'aria-disabled="true"' in row['html']
  if d['target']=='candidate':
   assert 'button "Inspect"' in d['states'][-1]['aria'] and 'button "Pin"' in d['states'][-1]['aria']
 counts={}
 for video in ['capture.mp4','frame-index-replay.mkv']:
  probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames,width,height','-of','json',str(base/video)]))['streams'][0];counts[video]=int(probe['nb_read_frames'])
 assert counts['frame-index-replay.mkv']==len(d['frames'])
 # MP4 count loss is retained and disclosed; FFV1 must preserve every original.
 audit=next(x for x in json.loads((r/'timestamp-audit.json').read_text()) if x['run']==str(base.relative_to(r)))
 assert counts['capture.mp4']==audit['decodedFrames']
 assert len(d['frames'])==audit['originalFrames']
 dec=subprocess.Popen(['ffmpeg','-v','error','-i',str(base/'frame-index-replay.mkv'),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
 for f in d['frames']:
  im=Image.open(base/f['file']).convert('RGB');expected=im.tobytes();chunks=[];left=len(expected)
  while left:
   b=dec.stdout.read(left);assert b,'truncated decode';chunks.append(b);left-=len(b)
  assert hashlib.sha256(b''.join(chunks)).digest()==hashlib.sha256(expected).digest(),str(base/f['file'])
 assert not dec.stdout.read(1);assert dec.wait()==0
 results.append({'run':str(base.relative_to(r)),'originalFrames':len(d['frames']),'decoded':counts,'rgbReplayExact':True,'failures':[x['name'] for x in d['checks'] if not x['pass']]})
assert len(results)==20
print(json.dumps({'verified':True,'runs':results},indent=2))
