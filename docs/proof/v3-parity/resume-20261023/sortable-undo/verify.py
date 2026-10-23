#!/usr/bin/env python3
"""Offline integrity verification. --require-parity also rejects native assertion failures."""
import hashlib,json,pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((root/'archive-sha256.json').read_text())
for rel,digest in manifest.items():
 assert sha(root/rel)==digest, f'hash mismatch: {rel}'
b=json.loads((root/'bindings.json').read_text())
for rel,digest in b['candidateFiles'].items():assert sha(root/'candidate'/rel)==digest,rel
for rel,digest in b['sourceFiles'].items():assert sha(root/'source'/rel)==digest,rel
assert sha(root/'candidate/example/build/web/main.dart.js')==b['candidateMainJs']
assert sha(root/'source/source.js')==b['sourceJs']
assert sha(root/'sortable_list_test.dart')==b['testSha256']
assert sha(root/'baseline-sortable_list.dart')==b['baselineSha256']
for row in json.loads((root/'source-inputs.json').read_text()):assert sha(root/row['archive'])==row['sha256']
print(f'Verified {len(manifest)} archived files and exact source/candidate input bindings.')
failures=[]
for path in sorted(root.glob('attempt-*/*/results.json')):
 d=json.loads(path.read_text());base=path.parent
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 assert len(d['frames'])==len(list((base/'original-frames').glob('*.png')))
 for s in d['states']:assert sha(base/s['screenshot']['file'])==s['screenshot']['sha256']
 for s in d['scripts']:assert sha(root/'served-js'/(s['sha256']+'.js'))==s['sha256']
 expected=b['sourceJs'] if d['target']=='source' else b['candidateMainJs']
 assert any(s['sha256']==expected for s in d['scripts']), 'served build not bound'
 assert all(e['isTrusted'] for scenario in d['inputs'] for e in scenario['events'])
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames','-of','json',str(base/'capture.mp4')]))
 decoded=int(probe['streams'][0]['nb_read_frames'])
 if decoded!=len(d['frames']):
  limit=json.loads((base/'MEDIA_LIMIT.json').read_text())
  assert decoded==limit['timestampVideoDecodedFrames'] and len(d['frames'])==limit['timestampVideoOriginalFrames']
  replay=base/'rgb-index-replay.mp4'
  rp=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames,width,height','-of','json',str(replay)]))['streams'][0]
  assert int(rp['nb_read_frames'])==len(d['frames'])
  from PIL import Image
  raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(replay),'-f','rawvideo','-pix_fmt','rgb24','-'])
  size=rp['width']*rp['height']*3
  for i,f in enumerate(d['frames']):assert Image.open(base/f['file']).convert('RGB').tobytes()==raw[i*size:(i+1)*size]
  print(f'RETAINED MEDIA LIMIT: {base.relative_to(root)} timestamp video has {decoded}/{len(d["frames"])} frames; full RGB index replay verified, no timing claim.')
 bad=[c['name'] for c in d['checks'] if not c['pass']]
 print(f'{base.relative_to(root)}: {len(d["states"])} states, {len(d["frames"])} original frames, {decoded} decoded, {len(bad)} recorded assertion failures.')
 failures.extend((str(base.relative_to(root)),name) for name in bad)
 if base.parent.name=='attempt-4':
  for scenario in d['inputs']:
   if scenario['scenario']!='disabled':assert any(e['type']=='keyup' and e.get('key')=='Tab' for e in scenario['events'])
  # Recompute the central eligibility outcomes from recorded state, independently of check booleans.
  states={s['name']:s for s in d['states']}
  for name,order,count,undo in [('reject-move',['A','B','C'],1,False),('reject-undo-attempt',['A','B','C'],1,False),('accept-move',['B','A','C'],1,True),('accept-undo',['A','B','C'],2,False),('external-reset',['A','B','C'],1,False),('membership-reintroduced',['B','A','C'],1,False),('disabled-inputs',['A','B','C'],0,False)]:
   s=states[name];assert (s['order'],len(s['fixture']['calls']),s['undo'])==(order,count,undo), f'{base.name}/{name}'
  for mode in ['accept','uncontrolled']:
   assert states[mode+'-undo']['fixture']['calls']==[['B','A','C'],['A','B','C']]
for path in root.glob('attempt-5-direct/*/results.json'):
 d=json.loads(path.read_text());states={s['name']:s for s in d['states']}
 for name in ['reject-move','reject-undo-attempt']:
  s=states[name];assert s['order']==['A','B','C'] and s['fixture']['calls']==[['B','A','C']] and not s['undo']
  assert 'Previous order restored.' not in s['aria']
 keys=[e['key'] for e in d['inputs'][0]['events'] if e['type']=='keyup']
 assert keys[-1]=='ArrowDown' and all(k=='Tab' for k in keys[:-1]) and len(keys)>=2
for path in root.glob('attempt-1/*/interrupted.json'):
 d=json.loads(path.read_text());base=path.parent
 for f in d['frames']:assert sha(base/f['file'])==f['sha256']
 decoded=int(json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames','-of','json',str(base/'interrupted-index-replay.mp4')]))['streams'][0]['nb_read_frames'])
 assert decoded==d['originalFrames']==d['decodedFrames']
 print(f'{base.relative_to(root)}: interrupted, {decoded} frames preserved in index replay; no timing claim.')
print(f'Integrity verified. {len(failures)} retained native assertion failures across all attempts; see results.json and README.md. This is not full parity approval.')
if '--require-parity' in sys.argv and failures:sys.exit(1)
