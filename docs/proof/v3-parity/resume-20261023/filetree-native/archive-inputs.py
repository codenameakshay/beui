from pathlib import Path
import shutil,json,hashlib,subprocess
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261023/filetree-native';t=Path('/tmp/beui-filetree-native-20261024');h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shutil.copytree(t/'source',o/'source',dirs_exist_ok=True)
shutil.copytree(t/'candidate/example/build/web',o/'candidate-build',dirs_exist_ok=True)
shutil.copy(t/'candidate.tar',o/'candidate-baseline.tar')
(o/'candidate-inputs').mkdir(exist_ok=True)
for f in ['pubspec.yaml','example/pubspec.yaml','example/pubspec.lock','example/.dart_tool/package_config.json','lib/src/motion/file_tree.dart']:
 dest=o/'candidate-inputs'/f;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy(t/'candidate'/f,dest)
bindings=[]
for x in json.loads((t/'source/inputs.json').read_text())['inputs']:
 p=Path(x['path']);p=p if p.is_absolute() else r/p;sha=h(p);assert sha==x['sha256'];dest=o/'source-inputs'/sha;dest.parent.mkdir(exist_ok=True);shutil.copy(p,dest);bindings.append({**x,'archive':str(dest.relative_to(o))})
(o/'source-input-bindings.json').write_text(json.dumps(bindings,indent=2))
for src,name in [('/tmp/beui-charts-fixture-runtime-20261023/package-lock.json','source-runtime-lock.json'),('/tmp/beui-multiselect-native-20261023/deps/package-lock.json','lucide-lock.json'),('/tmp/beui-parity-capture-runtime/package-lock.json','capture-lock.json'),('/tmp/filetree-build.log','candidate-build.log'),('/tmp/filetree-source-build.log','source-build.log')]:shutil.copy(src,o/name)
(o/'flutter-version.txt').write_bytes(subprocess.check_output(['flutter','--version']))
shutil.copy('/tmp/archive-filetree.py',o/'archive-inputs.py')
