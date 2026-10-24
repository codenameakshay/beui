from pathlib import Path
import hashlib,json,subprocess,shutil
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261023/multiselect-tab';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shutil.copy2(r/'test/motion/multi_select_test.dart',o/'inputs/final_multi_select_test.dart')
source=Path('/tmp/beui-charts-reference-20261023')
for b in json.loads((o/'source-input-bindings.json').read_text()):
 raw=subprocess.check_output(['git','-C',str(source),'show','a76e57c9:'+b['source']]);assert raw==(o/b['archive']).read_bytes()
bindings=[]
for i,entry in enumerate(json.loads((o/'source/inputs.json').read_text())['inputs']):
 p=Path(entry['path']);p=p if p.is_absolute() else r/p
 assert sha(p)==entry['sha256']
 dest=o/'source-build-inputs'/f'{i:04d}{p.suffix}';dest.parent.mkdir(exist_ok=True);shutil.copy2(p,dest)
 bindings.append({**entry,'archive':str(dest.relative_to(o))})
(o/'source-build-bindings.json').write_text(json.dumps(bindings,indent=2))
files={str(p.relative_to(o)):sha(p) for base in ['candidate/lib','candidate/assets','candidate/shaders','candidate/test','candidate/example/lib','candidate/example/assets','candidate/example/web','source-inputs','source-build-inputs','inputs'] for p in (o/base).rglob('*') if p.is_file()}
for name in ['candidate/pubspec.yaml','candidate/pubspec.lock','candidate/example/pubspec.yaml','candidate/example/pubspec.lock','fixture.dart','source.tsx','source.css','capture-runtime-package-lock.json','build_source.mjs','capture.mjs','source/package-lock.json']:
 p=o/name
 if p.exists():files[name]=sha(p)
(o/'input-lock.json').write_text(json.dumps(files,indent=2))
(o/'exact-hashes.json').write_text(json.dumps({'sourcePin':'a76e57c9bbc2837e96420b2610e9c82a3271bb05','priorMultiSelect':sha(o/'inputs/before.dart'),'files':{str(p.relative_to(o)):sha(p) for p in [o/'candidate/lib/src/motion/multi_select.dart',o/'inputs/final_multi_select_test.dart',o/'candidate/example/build/web/main.dart.js',o/'source/source.js']},'sdk':subprocess.check_output(['flutter','--version'],text=True)},indent=2))
