import os, pathlib, subprocess, json, hashlib, datetime, shutil
ROOT=pathlib.Path(__file__).resolve().parents[5]
OUT=pathlib.Path(__file__).resolve().parent
FILES=['lib/src/motion/collapsible.dart','test/motion/collapsible_test.dart','lib/src/motion/combobox.dart','test/motion/combobox_test.dart','lib/src/motion/availability_scheduler/copy_menu.dart','test/motion/availability_scheduler_test.dart']
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 return {'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'head':git('rev-parse','HEAD'),'files':{f:{'sha256':sha(ROOT/f),'head_sha256':hashlib.sha256(subprocess.check_output(['git','show','HEAD:'+f],cwd=ROOT)).hexdigest()} for f in FILES},'status':git('status','--short','--', 'lib','test','example','pubspec.yaml','pubspec.lock'),'free_bytes':shutil.disk_usage(ROOT).free,'inputs':{str(p.relative_to(ROOT)):sha(p) for base in ['lib','test','example/lib','example/test'] for p in (ROOT/base).rglob('*') if p.is_file() and ('failures' not in p.parts) and p.suffix in ['.dart','.png']}}
def save(name,d): (OUT/name).write_text(json.dumps(d,indent=2)+'\n')
env=os.environ.copy(); env.pop('BEUI_SKIP_GOLDENS',None)
save('before.json',snapshot())
with (OUT/'sdk.log').open('w') as f: subprocess.run(['flutter','--version'],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT)
commands=[('root',ROOT,['flutter','test','--no-pub','--reporter=json']),('gallery',ROOT/'example',['flutter','test','--no-pub','--reporter=json']),('root-analysis',ROOT,['flutter','analyze','--no-pub']),('gallery-analysis',ROOT/'example',['flutter','analyze','--no-pub']),('affected-analysis',ROOT,['flutter','analyze','--no-pub',*FILES]),('root-format',ROOT,['dart','format','--output=none','--set-exit-if-changed','.']),('gallery-format',ROOT/'example',['dart','format','--output=none','--set-exit-if-changed','.'])]
results=[]
for name,cwd,cmd in commands:
 before=snapshot(); save(name+'-before.json',before)
 if before['free_bytes']<200*1024*1024:
  save('space-blocker.json',{'gate':name,'snapshot':before}); break
 print('Starting',name,flush=True)
 start=datetime.datetime.now(datetime.timezone.utc).isoformat()
 with (OUT/(name+('.jsonl' if name in ['root','gallery'] else '.log'))).open('w') as stdout, (OUT/(name+'.stderr')).open('w') as stderr:
  p=subprocess.run(cmd,cwd=cwd,env=env,stdout=stdout,stderr=stderr)
 results.append({'gate':name,'cwd':str(cwd),'argv':cmd,'start':start,'exit_code':p.returncode,'end':datetime.datetime.now(datetime.timezone.utc).isoformat()})
 save('commands.json',results); save(name+'-after.json',snapshot())
 print('Finished',name,p.returncode,flush=True)
save('after.json',snapshot())
