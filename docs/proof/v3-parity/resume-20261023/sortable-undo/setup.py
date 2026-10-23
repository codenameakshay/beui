import shutil,pathlib
r=pathlib.Path('/tmp/beui-sortable-undo'); repo=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2')
for name in ['lib','assets','shaders']:
 shutil.copytree(repo/name,r/'candidate'/name,dirs_exist_ok=True)
for name in ['pubspec.yaml','pubspec.lock']:
 shutil.copy2(repo/name,r/'candidate'/name)
for name in ['web','assets/fonts']:
 shutil.copytree(repo/'example'/name,r/'candidate/example'/name,dirs_exist_ok=True)
(r/'candidate/example/pubspec.yaml').write_text('''name: sortable_fixture
publish_to: none
environment:
  sdk: ^3.12.2
dependencies:
  flutter:
    sdk: flutter
  beui:
    path: ../
flutter:
  uses-material-design: true
  fonts:
    - family: Geist
      fonts:
        - asset: assets/fonts/Geist-Regular.ttf
''')
for name in ['components/motion/sortable-list.tsx','lib/ease.ts','lib/utils.ts']:
 p=r/'source'/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(pathlib.Path('/tmp/beui-charts-reference-20261023')/name,p)
for name in ['package.json','package-lock.json']:
 shutil.copy2(pathlib.Path('/tmp/beui-charts-fixture-runtime-20261023')/name,r/'source'/name)
(r/'source/index.html').write_text('<!doctype html><html><head><link rel="stylesheet" href="source.css"></head><body><div id="root"></div><script src="source.js"></script></body></html>')
(r/'source/source.css').write_text('body{font:16px sans-serif;background:white;color:#111}main{width:420px;margin:120px auto}ul{list-style:none;padding:0}li{display:flex;align-items:center;gap:8px;padding:12px;border:1px solid #ddd;border-radius:16px;margin-bottom:8px}button{padding:8px}button:focus-visible{outline:2px solid blue}.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}')
