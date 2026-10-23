from pathlib import Path
import shutil,json,subprocess
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261023/returns-calendar-native';old=o.parent/'heat-calendar-native';t=Path('/tmp/beui-returns-native-20261023');t.mkdir()
for n in ['lib','assets','shaders']:
 if (r/n).exists():shutil.copytree(r/n,t/'candidate'/n)
for n in ['pubspec.yaml','pubspec.lock']:shutil.copy2(r/n,t/'candidate'/n)
shutil.copytree(r/'example',t/'candidate/example',ignore=shutil.ignore_patterns('build','.dart_tool','.git','ios','android','macos','linux','windows'))
a=[1,2,3,4,5,6,-1,-2,-3,-4,-5,-6];b=[2,-2,4,-4,6,-6,1,-1,3,-3,5,-5]
s={'initial':{'years':[2024,2025],'returns':[a,b]},'missing':{'years':[2024,2025],'returns':[a,b[:2]]},'replace':{'years':[2024,2030],'returns':[a,[7]*12]},'remove':{'years':[2024],'returns':[a]},'empty':{'years':[],'returns':[]}}
(o/'snapshots.json').write_text(json.dumps(s,indent=2));shutil.copy2(o/'snapshots.json',t/'candidate/example/assets/snapshots.json')
p=t/'candidate/example/pubspec.yaml';p.write_text(p.read_text().replace('  uses-material-design: true','  uses-material-design: true\n  assets:\n    - assets/snapshots.json'))
for n in ['source.css','build_source.mjs']:(o/n).write_text((old/n).read_text().replace('heat-calendar','returns-calendar'))
f=(old/'fixture.dart').read_text();start=f.index('if(data!=null)BeuiHeatCalendar');f=f[:start]+"if(data!=null)BeuiReturnsCalendar(years:[for(final y in data['years'])y as int],returns:[for(final row in data['returns'])[for(final v in row)(v as num).toDouble()]] )]))));}));}\n"
f=f.replace("LogicalKeyboardKey.keyB:'blank',LogicalKeyboardKey.keyR:'refresh',LogicalKeyboardKey.keyS:'shrink',LogicalKeyboardKey.keyD:'date'","LogicalKeyboardKey.keyM:'missing',LogicalKeyboardKey.keyR:'replace',LogicalKeyboardKey.keyD:'remove',LogicalKeyboardKey.keyE:'empty'").replace("['initial','blank','refresh','shrink','date']","['initial','missing','replace','remove','empty']")
(o/'fixture.dart').write_text(f);(t/'candidate/example/lib/main.dart').write_text(f)
f=(old/'source.tsx').read_text().replace('HeatCalendar','ReturnsCalendar').replace('heat-calendar','returns-calendar').replace("b:'blank',r:'refresh',s:'shrink',d:'date'","m:'missing',r:'replace',d:'remove',e:'empty'")
f=f.replace('weeks={data.weeks} values={data.values} maxCount={10} endDate={new Date(data.endDate+\'T00:00:00Z\')} color="#6366f1"','years={data.years} returns={data.returns}');(o/'source.tsx').write_text(f)
(o/'server.py').write_text("from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler\nimport os\nos.chdir('/tmp/beui-returns-native-20261023')\nThreadingHTTPServer(('127.0.0.1',18155),SimpleHTTPRequestHandler).serve_forever()\n")
(o/'base-head.txt').write_text(subprocess.check_output(['git','rev-parse','HEAD'],text=True));shutil.copy2('/tmp/setup-returns-native.py',o/'setup-original.py')
