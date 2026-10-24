from pathlib import Path
import json,subprocess
r=Path(__file__).resolve().parent
out=[]
for p in sorted(r.glob('attempt-*/*/results.json')):
 d=json.loads(p.read_text());frames=d['frames']
 pts=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_frames','-show_entries','frame=best_effort_timestamp_time','-of','json',str(p.parent/'capture.mp4')]))['frames']
 actual=[float(f['best_effort_timestamp_time']) for f in pts]
 expected=[f['metadata']['timestamp']-frames[0]['metadata']['timestamp'] for f in frames]
 out.append({'run':str(p.parent.relative_to(r)),'originalFrames':len(frames),'decodedFrames':len(actual),'maxRelativeTimestampErrorSeconds':max(abs(a-actual[0]-b) for a,b in zip(actual,expected)) if len(actual)==len(expected) else None})
print(json.dumps(out,indent=2))
