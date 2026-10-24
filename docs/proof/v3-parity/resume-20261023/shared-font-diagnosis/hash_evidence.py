import json,hashlib,pathlib
root=pathlib.Path('/tmp/beui-shared-font-diagnosis-20261023');out={}
for name,p in [('bump','/tmp/beui-bump-r4-after-20261023-v12'),('candle-fixture','/tmp/beui-round4-candle-volume-fixture-after-v13-20261023'),('candle-gallery','/tmp/beui-round4-candle-volume-gallery-after-v13-20261023'),('candle-source','/tmp/beui-round4-candle-volume-source-v2-20261023')]:
 b=pathlib.Path(p);files=[b/'main.dart.js',b/'source.js',b/'assets/FontManifest.json']+list((b/'assets/assets/fonts').glob('*.ttf'))+list(b.glob('*.ttf'))
 out[name]=[{ 'file':str(f),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in files if f.exists()]
for name in ['source-review-light-run1','verified-diff-dark-run1']:
 p=pathlib.Path('docs/proof/v3-parity/agents/round3')/name/'record.json';d=json.load(open(p));out[name]={k:d.get(k) for k in ['loaded','fontAssets','expectedJs']}
(root/'hash-evidence.json').write_text(json.dumps(out,indent=2))
print({k:[(pathlib.Path(f['file']).name,f['sha256']) for f in v[:3]] for k,v in out.items() if isinstance(v,list)})
