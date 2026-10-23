#!/usr/bin/env python3
"""Verify exported evidence without the original checkout, servers, or /tmp inputs."""
import pathlib,json,hashlib,subprocess,sys
r=pathlib.Path(__file__).resolve().parent
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((r/'archive-sha256.json').read_text())
for rel,digest in manifest.items():assert h(r/rel)==digest,rel
b=json.loads((r/'bindings.json').read_text())
for rel,digest in b['candidateFiles'].items():assert h(r/'candidate'/rel)==digest
for rel,digest in b['sourceFiles'].items():assert h(r/'source'/rel)==digest
for rel,key in [('baseline-sortable_list.dart','baselineComponent'),('candidate/lib/src/motion/sortable_list.dart','component'),('baseline-web/main.dart.js','baselineMainJs'),('candidate/example/build/web/main.dart.js','candidateMainJs'),('source/source.js','sourceJs'),('sortable_list_test.dart','testSha256'),('baseline-fixture.dart','baselineFixture'),('candidate/example/lib/main.dart','fixture')]:assert h(r/rel)==b[key]
for item in json.loads((r/'source-inputs.json').read_text()):assert h(r/item['archive'])==item['sha256']
failures=[]
latest=[]
for p in sorted(r.glob('attempt-*/*/results.json')):
 d=json.loads(p.read_text());base=p.parent;attempt=base.parent.name
 for f in d['frames']:assert h(base/f['file'])==f['sha256']
 assert len(d['frames'])==len(list((base/'original-frames').glob('*.png')))
 for s in d['states']:assert h(base/s['screenshot']['file'])==s['screenshot']['sha256']
 for s in d['scripts']:assert h(r/'served-js'/(s['sha256']+'.js'))==s['sha256']
 key='sourceJs' if d['target']=='source' else 'baselineMainJs' if attempt=='attempt-1-baseline' else 'candidateMainJs'
 assert any(s['sha256']==b[key] for s in d['scripts']),str(p)
 assert all(e['isTrusted'] for group in d['inputs'] for e in group['events'])
 assert any(e['type']=='keyup' and e.get('key')=='ArrowDown' for group in d['inputs'] for e in group['events'])
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames','-of','json',str(base/'capture.mp4')]))
 count=int(probe['streams'][0]['nb_read_frames'])
 if count!=len(d['frames']):
  limit=json.loads((base/'MEDIA_LIMIT.json').read_text());assert limit['timestampVideoDecodedFrames']==count;assert limit['timestampVideoOriginalFrames']==len(d['frames'])
  replay=base/'rgb-index-replay.mp4'
  rp=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames,width,height','-of','json',str(replay)]))['streams'][0]
  assert int(rp['nb_read_frames'])==len(d['frames'])
  from PIL import Image
  raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(replay),'-f','rawvideo','-pix_fmt','rgb24','-']);size=rp['width']*rp['height']*3
  for i,f in enumerate(d['frames']):assert Image.open(base/f['file']).convert('RGB').tobytes()==raw[i*size:(i+1)*size]
  print('RGB index replay verified; timestamp loss retained:',base.relative_to(r))
 bad=[c['name'] for c in d['checks'] if not c['pass']]
 failures.extend(bad)
 # Independently derive final behavioral failures from observations, not stored pass flags.
 states={s['name']:s for s in d['states']}
 expected=[]
 if attempt=='attempt-2-focus-nodes':
  expected=[('reject-move',['A','B','C'],1,False,'A'),('accept-move',['B','A','C'],1,True,'A'),('external-reset',['A','B','C'],1,False,None),('membership-reintroduced',['B','A','C'],1,False,None),('disabled-inputs',['A','B','C'],0,False,None)]
  for mode in ['accept','uncontrolled']:
   expected.extend([(mode+'-undo',['A','B','C'],2,False,'A'),(mode+'-end',['B','C','A'],3,True,'A'),(mode+'-home',['A','B','C'],4,True,'A'),(mode+'-home-undo',['B','C','A'],5,False,'B')])
 if attempt=='attempt-3-uninterrupted':
  expected=[('focused',['A','B','C'],0,False,'A'),('move',['B','A','C'],1,True,'A'),('end',['B','C','A'],2,True,'A'),('home',['A','B','C'],3,True,'A'),('home-undo',['B','C','A'],4,False,'B')]
  events=d['inputs'][0]['events'];keys=[e.get('key') for e in events if e['type']=='keyup'];i=keys.index('ArrowDown');assert keys[i:]==['ArrowDown','End','Home'],keys
 for name,order,calls,undo,focus in expected:
  s=states[name];ok=(s['order'],len(s['fixture']['calls']),s['undo'])==(order,calls,undo)
  if focus:ok=ok and (s['focus']['label']==f'Reorder {focus}' or s['focus']['text']==f'Reorder {focus}')
  if not ok:latest.append(f'{base.relative_to(r)}/{name}')
 if attempt!='attempt-1-baseline':latest.extend(str(base.relative_to(r))+'/'+x for x in bad if x!='decoded frame count')
 print(f'{base.relative_to(r)}: {len(d["states"])} states; {len(d["frames"])} original/{count} decoded; {len(bad)} recorded failures')
assert len(list(r.glob('attempt-*/*/results.json')))==12
print(f'Integrity verified: {len(manifest)} hashes. Historical and current recorded failures: {len(failures)}. Current strict outcome: {"FAIL" if latest else "PASS"}.')
if '--require-parity' in sys.argv and latest:sys.exit(1)
