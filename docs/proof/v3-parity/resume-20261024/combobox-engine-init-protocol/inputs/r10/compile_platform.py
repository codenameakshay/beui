from pathlib import Path
import subprocess,json,time,os
s=Path('/tmp/beui-gallery-engine-causal-r10'); cache=s/'sdk/bin/cache'; dart=cache/'dart-sdk'; web=cache/'flutter_web_sdk'
cmd=[str(dart/'bin/dartaotruntime'),str(dart/'bin/snapshots/kernel_worker_aot.dart.snapshot'),'--no-summary-only','--null-environment','--target','dart2js','--packages-file',(s/'empty-packages.json').as_uri(),'--multi-root-scheme','org-dartlang-sdk','--multi-root',web.as_uri(),'--libraries-file','org-dartlang-sdk:///libraries.json','--output',str(web/'kernel/dart2js_platform.dill')]
for lib in ['core','ui','ui_web','_engine','_skwasm_stub','_web_locale_keymap']:cmd+=['--source','dart:'+lib]
cmd+=['--multi-root',cache.as_uri()]
t=time.time();p=subprocess.run(cmd,stdout=open(s/'logs/platform-compile.log','w'),stderr=subprocess.STDOUT,env={**os.environ,'PUB_CACHE':str(s/'pub-cache')});(s/'platform-command.json').write_text(json.dumps({'command':cmd,'exit':p.returncode,'seconds':time.time()-t},indent=2));print(p.returncode)
