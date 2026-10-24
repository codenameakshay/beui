import pathlib,subprocess,os,json,time,sys
root=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2')
p=root/'docs/proof/v3-parity/resume-20261024/final-golden-triage'
label=sys.argv[1]; sdk=sys.argv[2]; cwd=sys.argv[3]
env=dict(os.environ); env.pop('BEUI_SKIP_GOLDENS',None); env['FLUTTER_SUPPRESS_ANALYTICS']='true'
files=sorted(set('test/'+s.split(': ',1)[0] for s in (root/'docs/proof/v3-parity/resume-20261024/components-integration/failure-identities.txt').read_text().splitlines()))
commands=[['--version','--machine'],['pub','get','--offline'],['test','--no-pub','--reporter=json','--name','golden|chat app shell|message bubble variants|streaming response endings',*files]]
for i,args in enumerate(commands):
 start=time.time(); cmd=[sdk+'/bin/flutter',*args]
 with (p/f'{label}-{i}.log').open('w') as out, (p/f'{label}-{i}.stderr').open('w') as err: r=subprocess.run(cmd,cwd=cwd,env=env,stdout=out,stderr=err)
 (p/f'{label}-{i}.command.json').write_text(json.dumps(dict(argv=cmd,cwd=cwd,skip_goldens=None,exit=r.returncode,seconds=time.time()-start),indent=2))
 print(label,i,r.returncode,flush=True)
 if r.returncode and i<2: break
