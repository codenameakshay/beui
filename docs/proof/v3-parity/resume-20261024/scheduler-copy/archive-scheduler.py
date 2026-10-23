from pathlib import Path
import hashlib,json,shutil,subprocess
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261024/scheduler-copy';t=Path('/tmp/beui-scheduler-copy-20261024')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shutil.copytree(t/'source',o/'source',dirs_exist_ok=True)
shutil.copytree(t/'candidate',o/'candidate',dirs_exist_ok=True,ignore=shutil.ignore_patterns('.dart_tool','node_modules','.git'))
shutil.copy(t/'candidate-build.log',o/'candidate-build.log')
bindings=[]
for e in json.loads((o/'source/inputs.json').read_text())['inputs']:
 p=Path(e['path']);p=p if p.is_absolute() else r/p
 dest=o/'source-inputs'/e['sha256'];dest.parent.mkdir(exist_ok=True);shutil.copyfile(p,dest)
 assert sha(dest)==e['sha256']
 bindings.append({**e,'archive':str(dest.relative_to(o))})
(o/'source-input-bindings.json').write_text(json.dumps(bindings,indent=2))
source=Path('/tmp/beui-charts-reference-20261023');sources=[]
for rel in ['components/motion/availability-scheduler/copy-menu.tsx','components/motion/availability-scheduler/index.tsx','components/motion/availability-scheduler/icon-button.tsx','components/motion/checkbox.tsx','components/previews/blocks/availability-scheduler.preview.tsx']:
 b=subprocess.check_output(['git','-C',str(source),'show','a76e57c9:'+rel])
 sources.append({'path':rel,'sha256':sha(source/rel),'sameAsPin':hashlib.sha256(b).hexdigest()==sha(source/rel)})
candidate=[]
for rel in ['lib/src/motion/availability_scheduler/copy_menu.dart','lib/src/motion/availability_scheduler/availability_scheduler.dart','lib/src/motion/checkbox.dart','lib/src/overlay/beui_overlay.dart','example/lib/demos/availability_scheduler_demo.dart']:
 candidate.append({'path':rel,'sha256':sha(r/rel),'buildCopyMatches':sha(r/rel)==sha(t/'candidate'/rel)})
(o/'identity.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'sourcePin':subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip(),'candidateFiles':candidate,'sourceFiles':sources},indent=2))
shutil.copy('/tmp/beui-parity-capture-runtime/package-lock.json',o/'capture-runtime-package-lock.json')
(o/'flutter-version.txt').write_text(subprocess.check_output(['flutter','--version'],text=True))
lock={str(p.relative_to(o)):sha(p) for d in ['candidate','source','source-inputs'] for p in (o/d).rglob('*') if p.is_file()}
(o/'input-lock.json').write_text(json.dumps(lock,indent=2))
