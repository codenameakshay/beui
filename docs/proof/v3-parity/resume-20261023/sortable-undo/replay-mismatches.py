import pathlib,json,subprocess,hashlib
from PIL import Image
r=pathlib.Path(__file__).resolve().parent
for result in sorted(r.glob('attempt-*/*/results.json')):
 d=json.loads(result.read_text());base=result.parent
 original=len(d['frames']);decoded=int(json.loads((base/'ffprobe.json').read_text())['streams'][0]['nb_read_frames'])
 if decoded==original:continue
 replay=base/'rgb-index-replay.mp4'
 enc=subprocess.run(['ffmpeg','-nostdin','-v','warning','-framerate','25','-i',str(base/'original-frames/frame_%06d.png'),'-c:v','libx264rgb','-preset','ultrafast','-crf','0','-pix_fmt','rgb24',str(replay)],capture_output=True,text=True);assert enc.returncode==0,enc.stderr
 (base/'rgb-index-encode.log').write_text(enc.stderr)
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames,width,height','-of','json',str(replay)]));assert int(probe['streams'][0]['nb_read_frames'])==original
 (base/'rgb-index-ffprobe.json').write_text(json.dumps(probe,indent=2))
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(replay),'-f','rawvideo','-pix_fmt','rgb24','-']);size=probe['streams'][0]['width']*probe['streams'][0]['height']*3
 for i,f in enumerate(d['frames']):assert Image.open(base/f['file']).convert('RGB').tobytes()==raw[i*size:(i+1)*size],i
 (base/'MEDIA_LIMIT.json').write_text(json.dumps({'timestampVideoOriginalFrames':original,'timestampVideoDecodedFrames':decoded,'rgbIndexReplayFrames':original,'rgbEquality':'Every decoded RGB frame equals its original PNG converted to RGB.','limitation':'Timestamp video frame count mismatch is retained. The 25 fps index replay preserves every RGB frame but is not timing or native60 evidence.'},indent=2))
 print(base.name,original,decoded,'RGB replay verified')
