import pathlib,subprocess,json,os,tarfile,io,time,collections,shutil
root=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2'); out=root/'docs/proof/v3-parity/resume-20261024/final-golden-triage'; scratch=pathlib.Path('/tmp/beui-final-golden-triage')
rows=json.loads((out/'history.json').read_text()); groups=collections.defaultdict(list)
for r in rows:groups[r['author_commit']].append(r)
env=dict(os.environ);env.pop('BEUI_SKIP_GOLDENS',None);env['FLUTTER_SUPPRESS_ANALYTICS']='true'
for commit,group in groups.items():
 if group[0]['date'].startswith('2026-10'): continue
 label='author-pinned-'+commit[:9]; dest=scratch/label; dest.mkdir(exist_ok=True)
 paths=subprocess.check_output(['git','ls-tree','--name-only',commit],cwd=root,text=True).splitlines()
 data=subprocess.check_output(['git','archive',commit,*[n for n in ['lib','test','assets','shaders','pubspec.yaml','pubspec.lock'] if n in paths]],cwd=root)
 tarfile.open(fileobj=io.BytesIO(data)).extractall(dest,filter='data')
 sdk=scratch/('sdk-3.47.1' if group[0]['date'].startswith('2026-10') else 'sdk-3.44.4')
 (dest/'pubspec_overrides.yaml').write_text('dependency_overrides:\n  flutter_lucide: 1.11.0\n')
 commands=[['pub','get','--offline'],['test','--no-pub','--reporter=json','--name','golden|chat app shell|message bubble variants|streaming response endings',*sorted(set(r['file'] for r in group))]]
 for i,args in enumerate(commands):
  cmd=[str(sdk/'bin/flutter'),*args]; start=time.time()
  with (out/f'{label}-{i}.log').open('w') as o,(out/f'{label}-{i}.stderr').open('w') as e:r=subprocess.run(cmd,cwd=dest,env=env,stdout=o,stderr=e)
  (out/f'{label}-{i}.command.json').write_text(json.dumps(dict(argv=cmd,cwd=str(dest),commit=commit,exit=r.returncode,seconds=time.time()-start,skip_goldens=None),indent=2))
  print(label,i,r.returncode,flush=True)
  if i==0 and r.returncode:break
 shutil.copy2(dest/'pubspec.lock',out/f'{label}-pubspec.lock')
 for f in dest.glob('test/**/failures/*.png'):
  d=out/label/f.relative_to(dest);d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,d)
