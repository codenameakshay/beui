from pathlib import Path
import shutil,subprocess,os,json
r=Path('/tmp/beui-initial-edit-engine-r8'); w=r/'engine/src/flutter/lib/web_ui'; s=Path('/Users/codenameakshay/fvm/default/engine/src/flutter/lib/web_ui'); a=r/'instrumented'; a.mkdir(exist_ok=True)
paths=['lib/src/engine/text_editing/text_editing.dart','lib/src/engine/semantics/text_field.dart','test/engine/semantics/initial_edit_boundary_test.dart']
for name in paths:
 (a/name).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(w/name,a/name)
text=(w/paths[0]).read_text(); trace=text[text.index('final List<Map<String, Object?>> initialEditTrace'):text.index('/// Text editing singleton.')]
(w/'test/engine/semantics/initial_edit_trace.dart').write_text(trace)
for name in paths[:2]: shutil.copy2(s/name,w/name)
p=w/paths[2];p.write_text(p.read_text().replace("import 'text_field_test.dart' as existing;", "import 'text_field_test.dart' as existing;\nimport 'initial_edit_trace.dart';"))
env=dict(os.environ,PUB_CACHE=str(r/'pub-cache'),TMPDIR=str(r),CHROME_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
cmd=[str(r/'dart-sdk/bin/dart'),'run','dev/felt.dart','test','--compile','--run','--browser=chrome','--compiler=dart2js',paths[2]]
with (r/'logs/run-uninstrumented.log').open('w') as f: result=subprocess.run(cmd,cwd=w,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=90)
(r/'logs/run-uninstrumented-command.json').write_text(json.dumps({'argv':cmd,'cwd':str(w),'exitCode':result.returncode},indent=2))
for name in paths: shutil.copy2(a/name,w/name)
