import pathlib,os,subprocess,json,time,shutil
r=pathlib.Path(__file__).parent
env=os.environ.copy()
for key in ['PRESERVE_MOVE','RECOVER','PACE','BROWSER']: env.pop(key,None)
env.update(BUMP_URL='http://127.0.0.1:18147/',REVERSE='1')
for motion in ['no-preference','reduce']:
 name='min3442-20261023-'+motion
 env['MOTION']=motion
 cmd=['node',str(r/'beui-focus-production-reproduce.mjs'),'after',name]
 with (r/('native-'+motion+'.log')).open('w') as out: p=subprocess.run(cmd,env=env,stdout=out,stderr=subprocess.STDOUT)
 dest=r/('native-'+motion); shutil.move('/tmp/beui-focus-research-after-'+name,dest)
 (r/('native-'+motion+'-result.json')).write_text(json.dumps(dict(command=cmd,env={k:env[k] for k in ['BUMP_URL','REVERSE','MOTION']},exit=p.returncode),indent=2))
 print(motion,p.returncode,flush=True)
 if p.returncode: break
