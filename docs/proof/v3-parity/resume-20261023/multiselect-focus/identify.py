from pathlib import Path
import hashlib,json,subprocess,shutil
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261023/multiselect-focus';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shutil.copy2(r/'test/motion/multi_select_test.dart',o/'inputs/final_multi_select_test.dart')
shutil.copy2('/tmp/beui-parity-capture-runtime/package-lock.json',o/'capture-runtime-package-lock.json')
source=Path('/tmp/beui-charts-reference-20261023');bindings=[]
for p in (source/'components/motion/multi-select').glob('*.tsx'):
 b=subprocess.check_output(['git','-C',str(source),'show','a76e57c9:'+str(p.relative_to(source))]);assert b==p.read_bytes(); dest=o/'source-inputs'/p.name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(b);bindings.append({'source':str(p.relative_to(source)),'archive':str(dest.relative_to(o)),'sha256':sha(dest)})
(o/'source-input-bindings.json').write_text(json.dumps(bindings,indent=2))
files={str(p.relative_to(o)):sha(p) for base in ['candidate/lib','candidate/assets','candidate/shaders','candidate/example/lib','candidate/example/assets','candidate/example/web','source-inputs'] for p in (o/base).rglob('*') if p.is_file()}
for name in ['candidate/pubspec.yaml','candidate/pubspec.lock','candidate/example/pubspec.yaml','candidate/example/pubspec.lock','fixture.dart','source.tsx','source.css','capture-runtime-package-lock.json']:
 p=o/name
 if p.exists():files[name]=sha(p)
(o/'input-lock.json').write_text(json.dumps(files,indent=2))
(o/'exact-hashes.json').write_text(json.dumps({'sourcePin':subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip(),'priorMultiSelect':'5965a2e74edb3c9fd88f5bf80ee9463924b1c9a6064b0d04fde93bd178061cd9','files':{str(p.relative_to(o)):sha(p) for p in [o/'candidate/lib/src/motion/multi_select.dart',o/'inputs/final_multi_select_test.dart',o/'candidate/example/build/web/main.dart.js',o/'source/source.js']},'sdk':subprocess.check_output(['flutter','--version'],text=True)},indent=2))
