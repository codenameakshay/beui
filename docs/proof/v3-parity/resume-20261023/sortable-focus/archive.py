import pathlib,shutil,hashlib,json
r=pathlib.Path(__file__).resolve().parent
out=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2/docs/proof/v3-parity/resume-20261023/sortable-focus')
for p in r.iterdir():
 if p.name=='candidate':
  for name in ['lib','assets','shaders','pubspec.yaml','pubspec.lock','example/lib','example/web','example/assets/fonts','example/pubspec.yaml','example/pubspec.lock','example/build/web']:
   src=p/name;dst=out/'candidate'/name
   if src.is_dir():shutil.copytree(src,dst,dirs_exist_ok=True)
   else:dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 elif p.is_dir():shutil.copytree(p,out/p.name,dirs_exist_ok=True)
 else:shutil.copy2(p,out/p.name)
manifest={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*')) if p.is_file() and p.name!='archive-sha256.json'}
(out/'archive-sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
