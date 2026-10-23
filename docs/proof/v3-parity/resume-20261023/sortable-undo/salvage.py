import pathlib,json,hashlib,subprocess
r=pathlib.Path(__file__).resolve().parent
for d in (r/'attempt-1').iterdir():
 files=sorted((d/'original-frames').glob('*.png'))
 if not files:continue
 command=['ffmpeg','-nostdin','-v','warning','-framerate','25','-i',str(d/'original-frames/frame_%06d.png'),'-c:v','libx264','-preset','ultrafast','-crf','0','-pix_fmt','yuv444p',str(d/'interrupted-index-replay.mp4')]
 result=subprocess.run(command,capture_output=True,text=True);(d/'index-encode.log').write_text(result.stderr)
 probe=subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=nb_read_frames,codec_name,width,height','-of','json',str(d/'interrupted-index-replay.mp4')],text=True)
 (d/'index-ffprobe.json').write_text(probe)
 (d/'interrupted.json').write_text(json.dumps({'status':'Interrupted by redirect response-body error; no complete behavior report or timing metadata. Index replay is not timing proof.','originalFrames':len(files),'decodedFrames':int(json.loads(probe)['streams'][0]['nb_read_frames']),'frames':[{'file':str(p.relative_to(d)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]},indent=2))
