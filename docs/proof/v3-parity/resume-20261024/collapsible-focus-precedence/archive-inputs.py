from pathlib import Path
import hashlib,json,subprocess,shutil
r=Path('/tmp/collapsible-focus-precedence-20261024')
a=Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2/docs/proof/v3-parity/resume-20261024/collapsible-focus-precedence')
repo=a.parents[4]
def copy(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True)
 subprocess.run(['cp','-cR',str(src),str(dst)],check=True)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['source','candidate-build','source.tsx','build_source.mjs','capture.mjs']:
 copy(r/name,a/name)
for name in ['lib','assets','shaders','web','fixture.dart','pubspec.yaml','pubspec.lock']:
 copy(r/'candidate'/name,a/'candidate-inputs'/name)
for name in ['collapsible_test.dart']:
 copy(repo/'test/motion'/name,a/'tests/motion'/name)
copy(repo/'test/support.dart',a/'tests/support.dart')
copy(a/'originals/independent_review_test.dart',a/'tests/motion/independent_review_test.dart')
inputs=[]
meta=json.loads((r/'source/inputs.json').read_text())
pin=subprocess.check_output(['git','-C','/tmp/beui-charts-reference-20261023','rev-parse','HEAD'],text=True).strip()
for i,p in enumerate(meta['inputs']):
 src=(r/'source'/p).resolve() if not Path(p).is_absolute() else Path(p)
 if not src.exists():
  src=(repo/p).resolve()
 target=a/'source-inputs'/str(i)/src.name
 copy(src,target)
 row={'original':str(src),'file':str(target.relative_to(a)),'sha256':sha(target)}
 ref=Path('/tmp/beui-charts-reference-20261023').resolve()
 if src.is_relative_to(ref):
  rel=str(src.relative_to(ref)); original=subprocess.check_output(['git','-C',str(ref),'show',pin+':'+rel]); assert hashlib.sha256(original).hexdigest()==row['sha256']; row['gitPath']=rel
 inputs.append(row)
(a/'source-bindings.json').write_text(json.dumps({'pin':pin,'inputs':inputs},indent=2))
copy(Path('/tmp/beui-parity-capture-runtime/package-lock.json'),a/'capture-runtime-package-lock.json')
copy(Path('/tmp/beui-charts-fixture-runtime-20261023/package-lock.json'),a/'source-runtime-package-lock.json')
copy(Path('/Users/codenameakshay/fvm/default/packages/flutter/lib/src/widgets/focus_manager.dart'),a/'sdk/focus_manager.dart')
(a/'flutter-version.json').write_bytes(subprocess.check_output(['flutter','--version','--machine']))
lock={}
for folder in ['candidate-inputs','candidate-build','source','tests']:
 lock[folder]={str(p.relative_to(a)):sha(p) for p in sorted((a/folder).rglob('*')) if p.is_file()}
lock['production']={'path':'candidate-inputs/lib/src/motion/collapsible.dart','sha256':sha(repo/'lib/src/motion/collapsible.dart')}
(a/'build-lock.json').write_text(json.dumps(lock,indent=2))
