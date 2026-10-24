from pathlib import Path
import os,subprocess,json,time
r=Path('/tmp/beui-engine-init-r11');w=r/'engine/src/flutter/lib/web_ui'
env=dict(os.environ,PUB_CACHE=str(r/'pub-cache'),TMPDIR=str(r),CHROME_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',DART_SUPPRESS_ANALYTICS='true',CI='true')
cmd=[str(r/'dart-sdk/bin/dart'),'run','dev/felt.dart','test','--compile','--run','--browser=chrome','--compiler=dart2js','test/engine/semantics/initial_edit_boundary_test.dart','test/engine/semantics/text_field_test.dart','test/engine/text_editing_test.dart']
t=time.time()
with (r/'logs/final-uninstrumented.log').open('w') as f: p=subprocess.run(cmd,cwd=w,env=env,stdout=f,stderr=subprocess.STDOUT)
(r/'final-run.json').write_text(json.dumps(dict(command=cmd,cwd=str(w),exit=p.returncode,seconds=time.time()-t),indent=2))
print(p.returncode)
