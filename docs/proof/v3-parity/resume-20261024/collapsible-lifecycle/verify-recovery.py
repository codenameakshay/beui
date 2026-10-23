from pathlib import Path
import json, hashlib, subprocess, io
from PIL import Image
root=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((root/'recovery-manifest.json').read_text())
for name,h in manifest.items():
 p=root/name
 assert p.is_file() and not p.is_symlink(),name
 assert sha(p)==h,name
checkpoint=json.loads((root/'recovery-checkpoint.json').read_text())
for name,h in checkpoint['priorArchive'].items():assert sha(root/name)==h,name
for name,h in json.loads((root/'build-lock.json').read_text()).items():assert sha(root/name)==h,name
identity=json.loads((root/'candidate-identity.json').read_text())
for row in identity['files']:assert sha(root/'inputs/candidate'/row['path'])==row['builtSha256'],row['path']
assert sha(root/'inputs/candidate/lib/src/motion/collapsible.dart')==checkpoint['production']
bindings=json.loads((root/'source-bindings.json').read_text())
assert bindings['pin']=='a76e57c9bbc2837e96420b2610e9c82a3271bb05'
for row in bindings['inputs']:
 assert sha(root/row['file'])==row['sha256']
 if 'gitPath' in row:assert row['gitSha256']==row['sha256']
invalid=[];pngs=0
for p in sorted(root.rglob('*.png')):
 try:
  with Image.open(p) as im:im.load()
  pngs+=1
 except Exception as e:invalid.append({'file':str(p.relative_to(root)),'sha256':sha(p),'bytes':p.stat().st_size})
assert invalid==json.loads((root/'preserved-invalid-pngs.json').read_text()),invalid
runs=[]
accepted=['final/source-no-preference','final/source-reduce','recovery5/candidate-no-preference','recovery5/candidate-reduce']
for result in sorted(root.glob('*/*/results.json')):
 r=json.loads(result.read_text());folder=result.parent;name=str(folder.relative_to(root))
 for s in r['scripts']:assert sha(root/'served'/s['sha256'])==s['sha256']
 bundle='source/source.js' if r['target']=='source' else ('after-build/main.dart.js' if r['attempt'].startswith(('final','recovery')) else 'before-build/main.dart.js')
 assert sha(root/bundle) in [s['sha256'] for s in r['scripts']],name
 for s in r['states']:assert sha(folder/s['screenshot']['file'])==s['screenshot']['sha256']
 for f in r['frames']:assert sha(folder/f['file'])==f['sha256']
 if name in accepted:
  assert len(r['checks'])==24,name
  assert [c['name'] for c in r['checks'] if not c['pass']]==(['disposed'] if r['target']=='candidate' else []),name
  states={s['name']:s for s in r['states']};closed=1 if r['target']=='source' else 0
  c=states['external-close'];assert c['fixture']['calls']==[] and not c['fixture']['open']
  assert c['focus']['tag'] in ['BUTTON','FLT-SEMANTICS'] and c['focus']['text']=='Toggle'
  assert c['fixture']['reduce']==(r['reducedMotion']=='reduce')
  assert abs(c['fixture']['height']-closed)<.02 and 'textbox "Inside"' not in c['aria']
  for n in ['next-tab','outside-close','later-outside']:assert states[n]['focus']['label'].endswith('Outside'),n
  assert states['outside-close']['fixture']['calls']==[]
  assert states['rejected']['fixture']['calls']==[False] and states['rejected']['fixture']['open']
  assert states['uncontrolled-close']['fixture']['calls']==[False]
  assert abs(states['uncontrolled-close']['fixture']['height']-closed)<.02
  assert states['disabled']['fixture']['disabled'] and states['disabled']['fixture']['calls']==[]
  if r['target']=='source':assert not states['disposed']['fixture']['alive']
  base=states['initial']['fixture']['height']
  for n,d in [('grown',100),('shrunk',-20),('narrow',60),('hidden-reopen',180)]:assert abs(states[n]['fixture']['height']-base-d)<.05,n
  assert abs(states['hidden-growth']['fixture']['height']-closed)<.02
  for n,h in [('initial',40),('grown',140),('shrunk',20),('narrow',100),('hidden-growth',220),('hidden-reopen',220)]:assert abs(states[n]['fixture']['inner']-h)<.05,n
  assert not r['errors']
  assert all(i['isTrusted'] or (i['type']=='click' and i['tag']=='FLT-SEMANTICS-PLACEHOLDER') for i in r['inputs'])
 runs.append({'run':name,'frames':len(r['frames']),'checks':len(r['checks']),'failures':[c['name'] for c in r['checks'] if not c['pass']]})
assert all(any(r['run']==a for r in runs) for a in accepted)
for preference in ['no-preference','reduce']:
 r=json.loads((root/('recovery-disposal2/candidate-'+preference)/'results.json').read_text())
 assert len(r['checks'])==8 and all(c['pass'] for c in r['checks'])
 states={s['name']:s for s in r['states']}
 assert states['disabled']['fixture']['disabled'] and states['disabled']['fixture']['calls']==[]
 assert not states['disposed']['fixture']['alive'] and states['disposed']['fixture']['calls']==[]
 assert 'Toggle' not in states['disposed']['aria']
 assert r['reducedMotion']==preference

videos=[]
for video in sorted(list(root.rglob('*.mkv'))+list(root.rglob('*.mp4'))):
 if not video.stat().st_size:
  videos.append({'file':str(video.relative_to(root)),'status':'empty preserved failed encode'});continue
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=width,height,nb_read_frames','-of','json',str(video)]))['streams'][0]
 subprocess.run(['ffmpeg','-v','error','-i',str(video),'-f','null','-'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 row={'file':str(video.relative_to(root)),'decodedFrames':int(probe['nb_read_frames'])}
 if video.suffix=='.mkv':
  originals=[]
  for f in sorted((video.parent/'original-frames').glob('*.png')):
   try:
    with Image.open(f) as im:im.load()
    originals.append(f)
   except Exception:pass
  p=subprocess.Popen(['ffmpeg','-v','error','-i',str(video),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
  for f in originals:
   with Image.open(f) as im:assert p.stdout.read(im.width*im.height*3)==im.convert('RGB').tobytes(),str(f)
  assert p.stdout.read()==b'' and p.wait()==0,str(video)
  assert row['decodedFrames']==len(originals)
  row['rgbExactOriginals']=len(originals)
 videos.append(row)
print(json.dumps({'status':'archive verified; bounded acceptance only','accepted':accepted,'validPngs':pngs,'preservedInvalidPngs':invalid,'runs':runs,'videos':videos},indent=2))
