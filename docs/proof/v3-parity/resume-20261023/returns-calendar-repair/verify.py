from pathlib import Path
import hashlib,json,subprocess,sys
r=Path(__file__).resolve().parent
seal=json.loads((r/'archive-sha256.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,h in seal.items():
 p=r/name
 assert p.is_file() and not p.is_symlink() and sha(p)==h,name
for folder,script in [('worker-r1','verify-final.py'),('worker-r2','verify.py'),('parent-final','verify.py')]:
 result=subprocess.run([sys.executable,str(r/folder/script)],capture_output=True,text=True)
 assert result.returncode==0,(folder,result.stdout,result.stderr)
frames=videos=0
known_incomplete = {
 'worker-r2/attempt-2/source-no-preference': (528,529),
 'parent-final/attempt-final/candidate-reduce': (559,560),
}
observed_incomplete = {}
for p in r.rglob('results.json'):
 d=json.loads(p.read_text())
 if not isinstance(d,dict) or 'frames' not in d:continue
 for f in d['frames']:assert sha(p.parent/f['file'])==f['sha256']
 for s in d['states']:assert sha(p.parent/s['screenshot']['file'])==s['screenshot']['sha256']
 if (p.parent/'capture.mp4').exists():
  n=int(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(p.parent/'capture.mp4')],text=True))
  rel=str(p.parent.relative_to(r))
  if n!=len(d['frames']):
   assert known_incomplete.get(rel)==(n,len(d['frames'])),rel
   observed_incomplete[rel]=(n,len(d['frames']))
  frames+=len(d['frames']);videos+=1
assert observed_incomplete==known_incomplete
index=r/'parent-final/attempt-final/candidate-reduce/frame-index-replay.mkv'
n=int(subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(index)],text=True));assert n==560
index_check=json.loads(index.with_name('frame-index-verification.json').read_text());assert index_check['decodedRGBExactlyMatchesOriginalPNGs'] and index_check['frames']==560
from PIL import Image
pngs=sorted((index.parent/'original-frames').glob('*.png'))
w,h=Image.open(pngs[0]).size
decoder=subprocess.Popen(['ffmpeg','-v','error','-i',str(index),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
for png in pngs:assert decoder.stdout.read(w*h*3)==Image.open(png).convert('RGB').tobytes(),png
assert not decoder.stdout.read(1) and decoder.wait()==0
exact=json.loads((r/'parent-final/exact-final.json').read_text())
assert exact['candidateSource']==exact['lib/src/charts/returns_calendar.dart']
assert not exact['libraryCopyDifferences']
print(json.dumps({'hashes':len(seal),'decodedVideos':videos,'recordedFrames':frames,'finalNativeCheckpoints':122,'status':'PASS','knownIncompleteTimestampVideos':observed_incomplete,'supplementalReplay':'560 exact RGB frames, index playback only','limits':['Nonidentical DOM focus tags','No pixel/native60/screen-reader certification']}))
