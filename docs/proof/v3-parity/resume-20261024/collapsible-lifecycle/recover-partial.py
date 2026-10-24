from pathlib import Path
from PIL import Image
import json,hashlib,subprocess
root=Path(__file__).resolve().parent
for p in [root/'before-retry/candidate-no-preference',root/'final2/source-no-preference']:
 valid=[];invalid=[]
 for f in sorted((p/'original-frames').glob('*.png')):
  try:
   im=Image.open(f);im.load();valid.append({'file':str(f.relative_to(p)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
  except Exception as e:invalid.append({'file':str(f.relative_to(p)),'bytes':f.stat().st_size,'error':str(e)})
 (p/'partial-recovery.json').write_text(json.dumps({'reason':'ENOSPC interrupted recorder before results.json; capture timestamps were in memory and are unavailable. No behavioral success claim. All files retained.','validFrames':valid,'invalidFiles':invalid},indent=2))
 if valid and not (p/'partial-frame-index-replay.mkv').exists():
  r=subprocess.run(['ffmpeg','-nostdin','-v','warning','-framerate','25','-i',str(p/'original-frames/frame_%06d.png'),'-frames:v',str(len(valid)),'-c:v','ffv1','-pix_fmt','bgr0',str(p/'partial-frame-index-replay.mkv')],capture_output=True,text=True);(p/'partial-replay.log').write_text(r.stderr);assert r.returncode==0
 print(p.name,len(valid),len(invalid))
