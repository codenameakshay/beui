#!/usr/bin/env python3
"""Read-only integrity verifier. Requires Python 3, ffmpeg and ffprobe on PATH."""
import hashlib,json,pathlib,subprocess,sys
import functools,http.server,threading,urllib.request,urllib.parse
r=pathlib.Path(__file__).resolve().parent
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def read(p):return json.loads(p.read_text())
def check(ok,detail):
 if not ok:raise RuntimeError(detail)
m=read(r/'archive-sha256.json')
for k,v in m.items():
 p=r/k;check(p.is_file() and not p.is_symlink(),k);check(sha(p)==v['sha256'] and p.stat().st_size==v['bytes'],k)
actual={str(p.relative_to(r)) for p in r.rglob('*') if p.is_file()}
check(actual==set(m)|{'archive-sha256.json'},'unexpected or missing files')
for name in ['topology','upstream']:
 seal=read(r/name/'manifest.json');seal=seal.get('sha256',seal)
 for k,v in seal.items():check(sha(r/name/k)==v,f'{name}/{k}')
for k,v in read(r/'dependencies.json').items():check(sha(r/k)==v['sha256'],k)
for k,v in read(r/'topology/input-hashes.json').items():check(sha(r/'dependencies'/k)==v,k)
for entry in read(r/'upstream/input-hashes.json'):check(sha(r/'upstream'/entry['copy'])==entry['sha256'],entry['copy'])
class QuietHandler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(QuietHandler,directory=str(r)))
threading.Thread(target=server.serve_forever,daemon=True).start()
reports=[];total=0
for p in sorted((r/'topology').glob('attempt-*/*/results.json')):
 d=read(p);b=p.parent;frames=d['frames'];total+=len(frames)
 check(len(frames)==len(list((b/'original-frames').glob('*.png'))),str(p))
 for f in frames:check(sha(b/f['file'])==f['sha256'],f['file'])
 for s in d['states']:check(sha(b/s['screenshot']['file'])==s['screenshot']['sha256'],str(p)+' screenshot')
 for s in d['scripts']:
  f=r/'topology/served-js'/(s['sha256']+'.js');check(sha(f)==s['sha256'] and f.stat().st_size==s['bytes'],'served bytes '+str(p))
 build=r/'topology/source/source.js' if d['target']=='source' else r/'topology'/('no-sort-key-web/main.dart.js' if b.parent.name=='attempt-1-no-sort-key' else 'candidate/example/build/web/main.dart.js')
 check(any(s['sha256']==sha(build) for s in d['scripts']),'served build binding '+str(p))
 url='http://127.0.0.1:'+str(server.server_port)+'/'+urllib.parse.quote(str(build.relative_to(r)))
 with urllib.request.urlopen(url) as response:check(hashlib.sha256(response.read()).hexdigest()==sha(build),'export HTTP served bytes')
 check(all(e['isTrusted'] for g in d['inputs'] for e in g['events']),'untrusted event')
 keys=[e.get('key') for g in d['inputs'] for e in g['events'] if e['type']=='keyup'];check(keys[keys.index('ArrowDown'):]==['ArrowDown','End','Home'],'interrupted input')
 check(not d['errors'],'page errors')
 proc=subprocess.run(['ffmpeg','-v','error','-xerror','-i',str(b/'capture.mp4'),'-f','null','-'],capture_output=True,text=True)
 check(proc.returncode==0,'decode: '+proc.stderr)
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','json',str(b/'capture.mp4')]))
 count=int(probe['streams'][0]['nb_read_frames']);check(count==len(frames),'decoded frame count')
 expected=[('focused',['A','B','C'],0,False,'A'),('move',['B','A','C'],1,True,'A'),('end',['B','C','A'],2,True,'A'),('home',['A','B','C'],3,True,'A'),('home-undo',['B','C','A'],4,False,'B')]
 states={s['name']:s for s in d['states']};derived=[]
 for name,order,calls,undo,focus in expected:
  s=states[name]
  tests={'order':s['order']==order,'callbacks':s['fixture']['calls']==[x[1] for x in expected[1:calls+1]],'Undo':s['undo']==undo,'focus':s['focus']['label']==f'Reorder {focus}' or s['focus']['text']==f'Reorder {focus}'}
  derived.extend(name+' '+k for k,v in tests.items() if not v)
 bad=[c['name'] for c in d['checks'] if not c['pass']]
 check(derived==bad,'failure derivation '+str(p)+str((derived,bad)))
 expected_fail=0 if d['target']=='source' else 10 if b.parent.name=='attempt-1-no-sort-key' else 1
 check(len(bad)==expected_fail,'historical failure count')
 reports.append({'report':str(p.relative_to(r)),'original_frames':len(frames),'decoded_frames':count,'recorded_failures':bad})
check(len(reports)==8 and total==409,'report/frame inventory')
server.shutdown();server.server_close()
print(json.dumps({'integrity':'PASS','parity':'FAIL: rejected experiments, native engine blocker 194550','sealed_files':len(m),'sealed_bytes':sum(v['bytes'] for v in m.values()),'original_frames':total,'reports':reports},indent=2))
if '--require-parity' in sys.argv:sys.exit(1)
