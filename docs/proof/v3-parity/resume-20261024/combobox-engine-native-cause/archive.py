from pathlib import Path
import shutil,json,hashlib,re,subprocess
s=Path('/tmp/beui-gallery-engine-causal-r10');o=Path.cwd()/'docs/proof/v3-parity/resume-20261024/combobox-engine-native-cause'
def cp(a,b):
 if a.is_dir():shutil.copytree(a,b,dirs_exist_ok=True)
 else:b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(a,b)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p in s.iterdir():
 if p.name in ['logs','web','served'] or p.suffix in ['.py','.mjs','.json'] or re.match(r'(instrumented|baseline)-(initial|full)-',p.name):cp(p,o/p.name)
for config in ['.dart_tool/package_config.json','example/.dart_tool/package_config.json']:
 cp(s/'gallery'/config,o/'resolved'/config)
manifest={str(p.relative_to(s/'sdk')):sha(p) for p in (s/'sdk/bin/cache/flutter_web_sdk').rglob('*') if p.is_file()}
(o/'restored-baseline-web-sdk.json').write_text(json.dumps(manifest,indent=2))
shared={}
for p in (o/'baseline/sdk').rglob('*'):
 if p.is_file():
  rel=p.relative_to(o/'baseline/sdk');installed=Path('/Users/codenameakshay/fvm/default')/rel;shared[str(rel)]={'baseline':sha(p),'installedNow':sha(installed),'equal':sha(p)==sha(installed)}
(o/'shared-sdk-source-check.json').write_text(json.dumps(shared,indent=2))
js=(s/'web/instrumented/main.dart.js').read_text();i=js.index('case"TextInput.setClient"');(o/'compiled-channel-dispatch.txt').write_text(js[i:i+1850]+'\n'+ '\n'.join(line for line in js.splitlines() if line.startswith(('B.a7x=','B.a7C='))))
for name in ['baseline','instrumented']:
 (o/(name+'-build-manifest.json')).write_text(json.dumps({str(p.relative_to(s/'web'/name)):sha(p) for p in (s/'web'/name).rglob('*') if p.is_file()},indent=2))
# Retain a combined timeline without claiming cross-buffer order for equal timestamps.
d=json.loads((s/'instrumented-initial-3/combobox-reduce/results.json').read_text());timeline=[{**x,'event':'DOM.'+x['type']} for x in d['inputs']]+d['trace'];timeline.sort(key=lambda x:x['time']);(o/'causal-timeline.json').write_text(json.dumps(timeline,indent=2))
