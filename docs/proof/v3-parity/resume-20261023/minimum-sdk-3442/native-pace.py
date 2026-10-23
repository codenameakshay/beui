import pathlib,os,subprocess,json,shutil
r=pathlib.Path(__file__).parent; env=os.environ.copy()
for key in ['PRESERVE_MOVE','RECOVER','PACE','BROWSER']: env.pop(key,None)
env.update(BUMP_URL='http://127.0.0.1:18147/',REVERSE='1',MOTION='no-preference')
for i in [16,30,50,100]:
 env["PACE"]=str(i)
 name='min3442-20261023-pace'+str(i); cmd=['node',str(r/'beui-focus-production-reproduce.mjs'),'after',name]
 with (r/('pace'+str(i)+'.log')).open('w') as out: p=subprocess.run(cmd,env=env,stdout=out,stderr=subprocess.STDOUT)
 dest=r/('pace'+str(i)); shutil.move('/tmp/beui-focus-research-after-'+name,dest)
 moves=[x for row in json.loads((dest/'trace.json').read_text()) for x in row if x['type']=='production-active-move']
 real=[x for x in moves if x['to'] not in [x['from'],x['from']+1]]
 (r/('pace'+str(i)+'-result.json')).write_text(json.dumps(dict(command=cmd,exit=p.returncode,moves=moves,actualReorders=real),indent=2))
 print(i,p.returncode,len(moves),len(real),flush=True)
 if p.returncode or real: break
