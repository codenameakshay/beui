import pathlib,shutil,subprocess,os,json,time
p=pathlib.Path('/tmp/beui-final-golden-triage'); out=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2/docs/proof/v3-parity/resume-20261024/final-golden-triage')
src=p/'current-3471';dst=p/'settled-charts-frames';shutil.copytree(src,dst,ignore=shutil.ignore_patterns('build','failures','.dart_tool'),dirs_exist_ok=True)
files=['bump_chart','candlestick_chart','donut_chart','order_book','volume_profile']
for name in files:
 f=dst/f'test/charts/{name}_test.dart';s=f.read_text();s=s.replace('await expectLater(', 'for (var frame = 0; frame < 40; frame++) { await tester.pump(const Duration(milliseconds: 100)); }\n    await expectLater(');f.write_text(s)
env=dict(os.environ);env.pop('BEUI_SKIP_GOLDENS',None)
for i,args in enumerate([['pub','get','--offline'],['test','--no-pub','--reporter=json','--name','golden',*[f'test/charts/{n}_test.dart' for n in files]]]):
 cmd=[str(p/'sdk-3.47.1/bin/flutter'),*args]
 with (out/f'settled-charts-frames-{i}.log').open('w') as o,(out/f'settled-charts-frames-{i}.stderr').open('w') as e:r=subprocess.run(cmd,cwd=dst,env=env,stdout=o,stderr=e)
 (out/f'settled-charts-frames-{i}.command.json').write_text(json.dumps(dict(argv=cmd,cwd=str(dst),exit=r.returncode),indent=2))
for f in dst.glob('test/**/failures/*.png'):
 d=out/'settled-charts-frames'/f.relative_to(dst);d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,d)
