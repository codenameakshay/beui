import pathlib,shutil,json,hashlib,subprocess
r=pathlib.Path(__file__).resolve().parent
out=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2/docs/proof/v3-parity/resume-20261023/sortable-undo')
# Keep every attempt, including originals from the interrupted recorder.
for p in r.iterdir():
 if p.name=='source':shutil.copytree(p,out/p.name,dirs_exist_ok=True,ignore=shutil.ignore_patterns('node_modules'))
 elif p.name=='candidate':
  for name in ['lib','assets','shaders','pubspec.yaml','pubspec.lock','example/lib','example/web','example/assets/fonts','example/pubspec.yaml','example/pubspec.lock','example/build/web']:
   src=p/name;dst=out/'candidate'/name
   if src.is_dir():shutil.copytree(src,dst,dirs_exist_ok=True)
   else:dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 elif p.is_dir():shutil.copytree(p,out/p.name,dirs_exist_ok=True)
 else:shutil.copy2(p,out/p.name)
