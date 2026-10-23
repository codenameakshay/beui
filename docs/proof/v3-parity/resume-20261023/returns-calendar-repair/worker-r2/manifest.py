from pathlib import Path
import json,hashlib
r=Path(__file__).resolve().parent
shared=Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
files={}
for root in ['candidate/lib','candidate/assets','candidate/shaders','candidate/example/lib','candidate/example/web','candidate/example/assets','candidate/example/build/web','source']:
 for p in (r/root).rglob('*'):
  if p.is_file():files[str(p.relative_to(r))]={'sha256':sha(p),'bytes':p.stat().st_size}
for n in ['candidate/pubspec.yaml','candidate/pubspec.lock','candidate/example/pubspec.yaml','candidate/example/pubspec.lock','capture.mjs']:
 p=r/n;files[n]={'sha256':sha(p),'bytes':p.stat().st_size}
(r/'final-input-hashes.json').write_text(json.dumps(files,indent=2))
checks={n:sha(shared/n) for n in ['lib/src/charts/returns_calendar.dart','test/charts/returns_calendar_native_regression_test.dart']}
checks['candidateSource']=sha(r/'candidate/lib/src/charts/returns_calendar.dart');checks['servedMain']=sha(r/'candidate/example/build/web/main.dart.js')
checks['libraryCopyDifferences']=[str(p.relative_to(shared)) for p in (shared/'lib').rglob('*') if p.is_file() and (not (r/'candidate'/p.relative_to(shared)).exists() or sha(p)!=sha(r/'candidate'/p.relative_to(shared)))]
(r/'exact-final.json').write_text(json.dumps(checks,indent=2))
