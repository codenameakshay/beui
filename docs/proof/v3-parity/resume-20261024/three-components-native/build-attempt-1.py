import pathlib,hashlib,json,subprocess,shutil,time
r=pathlib.Path.cwd();o=r/'docs/proof/v3-parity/resume-20261024/three-components-native'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
files=['lib/src/motion/collapsible.dart','test/motion/collapsible_test.dart','lib/src/motion/combobox.dart','test/motion/combobox_test.dart','lib/src/motion/availability_scheduler/copy_menu.dart','test/motion/availability_scheduler_test.dart']
inputs={str(p.relative_to(r)):sha(p) for base in ['lib','example/lib','example/web'] for p in (r/base).rglob('*') if p.is_file()}
for f in files+['pubspec.yaml','pubspec.lock','example/pubspec.yaml','example/pubspec.lock','example/.dart_tool/package_config.json']:
 inputs[f]=sha(r/f)
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(); assert head=='ee5b755599cead69fabf30079af1be9634f80280'
json.dump({'head':head,'inputs':inputs,'six':{f:inputs[f] for f in files},'free':shutil.disk_usage(r).free},open(o/'input-lock.json','w'),indent=2)
subprocess.run(['flutter','--version'],stdout=open(o/'sdk.txt','w'),stderr=subprocess.STDOUT)
assert shutil.disk_usage(r).free>700*1024**2
start=time.time();cmd=['flutter','build','web','--release','--no-pub']
p=subprocess.run(cmd,cwd=r/'example',stdout=open(o/'build.log','w'),stderr=subprocess.STDOUT)
json.dump({'argv':cmd,'cwd':str(r/'example'),'start':start,'end':time.time(),'exit':p.returncode,'freeAfter':shutil.disk_usage(r).free},open(o/'build-command.json','w'),indent=2)
assert p.returncode==0
json.dump({str(p.relative_to(r/'example/build/web')):sha(p) for p in (r/'example/build/web').rglob('*') if p.is_file()},open(o/'build-manifest.json','w'),indent=2)
json.dump({'unchanged':all(sha(r/f)==h for f,h in inputs.items())},open(o/'input-stability.json','w'))
