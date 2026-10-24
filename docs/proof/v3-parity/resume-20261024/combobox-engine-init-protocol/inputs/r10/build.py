from pathlib import Path
import os,subprocess,json,time
s=Path('/tmp/beui-gallery-engine-causal-r10');env={**os.environ,'FLUTTER_ROOT':str(s/'sdk'),'PUB_CACHE':str(s/'pub-cache'),'XDG_CONFIG_HOME':str(s/'config'),'FLUTTER_CONFIG_DIR':str(s/'config'),'FLUTTER_SUPPRESS_ANALYTICS':'true','DART_SUPPRESS_ANALYTICS':'true','CI':'true'}
(s/'home').mkdir(exist_ok=True)
cmd=[str(s/'sdk/bin/cache/dart-sdk/bin/dart'),str(s/'sdk/bin/cache/flutter_tools.snapshot'),'build','web','--release','--no-pub']
t=time.time();p=subprocess.run(cmd,cwd=s/'gallery/example',env=env,stdout=open(s/'logs/gallery-build.log','w'),stderr=subprocess.STDOUT);(s/'build-command.json').write_text(json.dumps({'command':cmd,'exit':p.returncode,'seconds':time.time()-t},indent=2));print(p.returncode)
