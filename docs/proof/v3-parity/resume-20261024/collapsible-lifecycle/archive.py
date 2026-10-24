from pathlib import Path
import shutil,json,hashlib,subprocess,ctypes
libc=ctypes.CDLL(None)
def clone(a,b):
 a,b=Path(a),Path(b)
 if b.exists():b.unlink()
 if libc.clonefile(str(a).encode(),str(b).encode(),0)!=0:shutil.copy2(a,b)
 return str(b)
r=Path('/tmp/beui-collapsible-lifecycle'); out=Path('docs/proof/v3-parity/resume-20261024/collapsible-lifecycle');out.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy(a,b):
 if a.is_dir():shutil.copytree(a,b,dirs_exist_ok=True,copy_function=clone)
 else:b.parent.mkdir(parents=True,exist_ok=True);clone(a,b)
for name in ['before','before-retry','final','final2','before-build','after-build','source','served']:
 if (r/name).exists():copy(r/name,out/name)
for p in r.iterdir():
 if p.is_file():copy(p,out/p.name)
copy(r/'candidate/lib',out/'inputs/candidate/lib')
for name in ['pubspec.yaml','pubspec.lock','fixture.dart']:copy(r/'candidate'/name,out/'inputs/candidate'/name)
copy(Path('/tmp/collapsible-before.dart'),out/'inputs/collapsible-before.dart')
copy(Path('test/motion/collapsible_test.dart'),out/'inputs/collapsible_test.dart')
copy(Path('/tmp/beui-parity-capture-runtime/package-lock.json'),out/'capture-runtime-package-lock.json')
copy(Path('/tmp/beui-charts-fixture-runtime-20261023/package-lock.json'),out/'source-runtime-package-lock.json')
meta=json.loads((r/'source/inputs.json').read_text());bindings=[];pin='a76e57c9bbc2837e96420b2610e9c82a3271bb05';ref=Path('/tmp/beui-charts-reference-20261023')
for i,name in enumerate(meta['inputs']):
 p=Path(name).resolve();dest=out/'source-inputs'/str(i)/p.name;copy(p,dest);row={'original':str(p),'file':str(dest.relative_to(out)),'sha256':sha(p)}
 if p.is_relative_to(ref):
  rel=str(p.relative_to(ref));gitbytes=subprocess.check_output(['git','-C',str(ref),'show',pin+':'+rel]);assert hashlib.sha256(gitbytes).hexdigest()==row['sha256'];row['gitPath']=rel;row['gitSha256']=hashlib.sha256(gitbytes).hexdigest()
 bindings.append(row)
(out/'source-bindings.json').write_text(json.dumps({'pin':pin,'inputs':bindings},indent=2))
(out/'build-lock.json').write_text(json.dumps({str(p.relative_to(out)):sha(p) for folder in ['before-build','after-build','source','inputs','source-inputs'] for p in (out/folder).rglob('*') if p.is_file()},indent=2))
