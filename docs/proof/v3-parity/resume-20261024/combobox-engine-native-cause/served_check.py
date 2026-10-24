from pathlib import Path
import hashlib,json,urllib.request
s=Path('/tmp/beui-gallery-engine-causal-r10');sv=json.loads((s/'server.json').read_text());root=s/'web'/sv['build'];d={}
for p in root.rglob('*'):
 if p.is_file():
  rel=str(p.relative_to(root));h=hashlib.sha256(p.read_bytes()).hexdigest();actual=hashlib.sha256(urllib.request.urlopen(f'http://127.0.0.1:{sv["port"]}/'+rel).read()).hexdigest();assert h==actual;d[rel]=h
(s/(sv['build']+'-served.json')).write_text(json.dumps(d,indent=2));print(sv['build'],len(d))
