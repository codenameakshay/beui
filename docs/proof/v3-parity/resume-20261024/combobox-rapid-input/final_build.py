import pathlib,shutil,hashlib,json,subprocess,time
r=pathlib.Path.cwd();s=pathlib.Path('/tmp/beui-rapid-input-20261024');c=s/'candidate';o=r/'docs/proof/v3-parity/resume-20261024/combobox-rapid-input'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
shutil.copytree(c/'example/build/web',o/'trace-web')
shutil.copy2(c/'lib/src/motion/combobox.dart',o/'baseline/combobox-instrumented.dart')
shutil.copy2(r/'lib/src/motion/combobox.dart',c/'lib/src/motion/combobox.dart')
files=[p for base in ['lib','assets','shaders','example/lib','example/web','example/assets'] if (c/base).exists() for p in (c/base).rglob('*') if p.is_file()]
files += [c/f for f in ['pubspec.yaml','pubspec.lock','.dart_tool/package_config.json','example/pubspec.yaml','example/pubspec.lock','example/.dart_tool/package_config.json','example/.dart_tool/package_graph.json']]
manifest={str(p.relative_to(c)):sha(p) for p in files}
for p in files:
 dst=o/'final-inputs'/p.relative_to(c);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
(o/'final-inputs.json').write_text(json.dumps(manifest,indent=2))
subprocess.run(['flutter','--version'],stdout=open(o/'sdk.txt','w'))
start=time.time();cmd=['flutter','build','web','--release','--no-pub'];result=subprocess.run(cmd,cwd=c/'example',stdout=open(o/'final-build.log','w'),stderr=subprocess.STDOUT)
(o/'final-build-command.json').write_text(json.dumps({'command':cmd,'cwd':str(c/'example'),'start':start,'end':time.time(),'exit':result.returncode,'inputsUnchanged':all(sha(c/f)==h for f,h in manifest.items())},indent=2))
assert result.returncode==0
shutil.copytree(c/'example/build/web',o/'final-web')
(o/'final-build-manifest.json').write_text(json.dumps({str(p.relative_to(o/'final-web')):sha(p) for p in (o/'final-web').rglob('*') if p.is_file()},indent=2))
