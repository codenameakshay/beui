from pathlib import Path
import shutil,json,subprocess
r=Path.cwd(); o=r/'docs/proof/v3-parity/resume-20261023/heat-calendar-native'; old=o.parent/'order-book-deterministic'; t=Path('/tmp/beui-heat-native-20261023');t.mkdir()
for n in ['lib','assets','shaders']: 
 if (r/n).exists():shutil.copytree(r/n,t/'candidate'/n)
for n in ['pubspec.yaml','pubspec.lock']:shutil.copy2(r/n,t/'candidate'/n)
shutil.copytree(r/'example',t/'candidate/example',ignore=shutil.ignore_patterns('build','.dart_tool','.git','ios','android','macos','linux','windows'))
v=[[0,.2,.4,.6,.8,1,0] for _ in range(4)]
s={k:{'weeks':w,'endDate':d,'values':a} for k,w,d,a in [('initial',4,'2026-10-23',v),('blank',4,'2026-10-23',[]),('refresh',4,'2026-10-23',[[1-x for x in col] for col in v]),('shrink',1,'2026-10-23',[v[0]]),('date',4,'2026-10-19',v)]}
(o/'snapshots.json').write_text(json.dumps(s,indent=2));shutil.copy2(o/'snapshots.json',t/'candidate/example/assets/snapshots.json')
p=t/'candidate/example/pubspec.yaml';p.write_text(p.read_text().replace('  assets:','  assets:\n    - assets/snapshots.json'))
for name in ['source.css','build_source.mjs']:(o/name).write_text((old/name).read_text().replace('order-book-deterministic','heat-calendar-native').replace('order-book','heat-calendar'))
(o/'server.py').write_text("from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler\nimport os\nos.chdir('/tmp/beui-heat-native-20261023')\nThreadingHTTPServer(('127.0.0.1',18149),SimpleHTTPRequestHandler).serve_forever()\n")
(o/'base-head.txt').write_text(subprocess.check_output(['git','rev-parse','HEAD'],text=True))
