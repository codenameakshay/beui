from pathlib import Path
import json,hashlib,shutil,subprocess
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261023/multiselect-native';t=Path('/tmp/beui-multiselect-native-20261023')
def cp(a,b):
 b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(a,b)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['source','candidate/lib','candidate/assets','candidate/shaders','candidate/example/lib','candidate/example/web','candidate/example/assets','candidate/example/build/web']:
 shutil.copytree(t/name,o/name)
for n in ['candidate/pubspec.yaml','candidate/pubspec.lock','candidate/example/pubspec.yaml','candidate/example/pubspec.lock','deps/package.json','deps/package-lock.json']:cp(t/n,o/n)
for n in ['setup-multiselect-native.py','beui-multiselect-build.log','beui-multiselect-deps.log']:cp(Path('/tmp')/n,o/n)
inputs=json.loads((t/'source/inputs.json').read_text());bindings=[]
for entry in inputs['inputs']:
 p=Path(entry['path']);p=p if p.is_absolute() else r/p
 key=entry['sha256']; dest=o/'source-inputs'/key
 cp(p,dest);assert sha(dest)==key
 bindings.append({**entry,'archive':'source-inputs/'+key})
(o/'source-input-bindings.json').write_text(json.dumps(bindings,indent=2))
sourcefiles=[]
for b in bindings:
 p=Path(b['path']).resolve();base=Path('/tmp/beui-charts-reference-20261023').resolve()
 if p.is_relative_to(base):
  relative=str(p.relative_to(base));gitbytes=subprocess.check_output(['git','-C',str(base),'show','a76e57c9:'+relative]);sourcefiles.append({'path':relative,'sha256':hashlib.sha256(gitbytes).hexdigest(),'sameAsPin':hashlib.sha256(gitbytes).hexdigest()==b['sha256']})
candidate=[]
for p in (o/'candidate/lib').rglob('*.dart'):
 rel=str(p.relative_to(o/'candidate'));b=subprocess.check_output(['git','show','1254bfa63:'+rel]);candidate.append({'path':rel,'sha256':sha(p),'sameAsHead':hashlib.sha256(b).hexdigest()==sha(p)})
(o/'identity.json').write_text(json.dumps({'candidateHead':'1254bfa63a70298061c557616abeb9c6a67db372','sourcePin':inputs['pinnedSource'],'sourceFiles':sourcefiles,'candidateFiles':candidate,'ports':[18161,18162]},indent=2))
(o/'input-lock.json').write_text(json.dumps({str(p.relative_to(o)):sha(p) for n in ['source','source-inputs','candidate','deps'] for p in (o/n).rglob('*') if p.is_file()},indent=2))
