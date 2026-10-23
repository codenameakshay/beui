from pathlib import Path
import ctypes,shutil,json,hashlib,subprocess
from PIL import Image
src=Path('/tmp/beui-collapsible-lifecycle');dst=Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2/docs/proof/v3-parity/resume-20261024/collapsible-lifecycle');libc=ctypes.CDLL(None)
for name in ['recovery4','recovery5','recovery-disposal','recovery-disposal2','capture-recovery.mjs','capture-recovery5.mjs','capture-recovery4.log','capture-recovery5.log','capture-disposal.mjs','capture-disposal.log','capture-disposal2.mjs','capture-disposal2.log','widget-recovery.log','verify-recovery.py','archive-recovery.py']:
 p=src/name
 for f in ([p] if p.is_file() else p.rglob('*')):
  if not f.is_file():continue
  out=dst/f.relative_to(src);out.parent.mkdir(parents=True,exist_ok=True)
  if out.exists():assert out.read_bytes()==f.read_bytes();continue
  if libc.clonefile(str(f).encode(),str(out).encode(),0)!=0:shutil.copyfile(f,out)
invalid=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for p in sorted(dst.rglob('*.png')):
 try:
  with Image.open(p) as im:im.load()
 except Exception:invalid.append({'file':str(p.relative_to(dst)),'sha256':sha(p),'bytes':p.stat().st_size})
(dst/'preserved-invalid-pngs.json').write_text(json.dumps(invalid,indent=2))
for folder in sorted(dst.glob('*/*/original-frames')):
 if list(folder.parent.glob('*.mkv')):continue
 valid=[]
 for p in sorted(folder.glob('*.png')):
  try:
   with Image.open(p) as im:im.load()
   valid.append(p)
  except Exception:pass
 if not valid:continue
 video=folder.parent/'recovered-frame-index-replay.mkv'
 process=subprocess.Popen(['ffmpeg','-v','error','-f','image2pipe','-framerate','25','-i','-','-c:v','ffv1','-pix_fmt','bgr0',str(video)],stdin=subprocess.PIPE)
 for p in valid:process.stdin.write(p.read_bytes())
 process.stdin.close();assert process.wait()==0
 (folder.parent/'recovery-note.json').write_text(json.dumps({'validFrames':len(valid),'timestamps':'unavailable without completed results; 25fps replay is frame-index only','originals':'All retained, including corrupt files'}))
print('Archived new artifacts and recovered replay files')
