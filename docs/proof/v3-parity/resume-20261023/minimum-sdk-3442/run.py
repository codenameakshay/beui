import os,pathlib,subprocess,json,time
r=pathlib.Path(__file__).parent
env=os.environ.copy(); env.update(HOME=str(r/'home'),PUB_CACHE=str(r/'pub-cache'),CI='true',FLUTTER_SUPPRESS_ANALYTICS='true')
f=str(r/'flutter/bin/flutter'); d=str(r/'flutter/bin/dart')
steps=[('sdk-version',[f,'--version','--machine'],r),('pub-get',[f,'pub','get'],r/'package'),('adapter-compile',[d,'compile','js','-O2','test/web/semantics_move_guard_entry.dart','-o',str(r/'semantics-guard.js')],r/'package'),('contract',['node','test/web/semantics_move_guard_contract.mjs',str(r/'semantics-guard.js'),str(r/'contract')],r/'package'),('example-pub-get',[f,'pub','get'],r/'package/example'),('bump-build',[f,'build','web','--release','--target=../test/charts/bump_parity_fixture.dart','--output='+str(r/'bump-web')],r/'package/example')]
env.update(PLAYWRIGHT_MODULE='/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs',CHROMIUM_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',REQUIRED_BROWSERS='chromium')
for name,cmd,cwd in steps:
 start=time.time()
 with (r/(name+'.log')).open('w') as out: result=subprocess.run(cmd,cwd=cwd,env=env,stdout=out,stderr=subprocess.STDOUT)
 (r/(name+'-result.json')).write_text(json.dumps(dict(command=cmd,cwd=str(cwd),exit=result.returncode,seconds=time.time()-start),indent=2))
 print(name,result.returncode,flush=True)
 if result.returncode: break
