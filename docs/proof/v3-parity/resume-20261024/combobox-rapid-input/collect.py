import pathlib,shutil,json,hashlib,urllib.request,urllib.parse
r=pathlib.Path.cwd();o=r/'docs/proof/v3-parity/resume-20261024/combobox-rapid-input';s=pathlib.Path('/tmp/beui-rapid-input-20261024')
for p in s.iterdir():
 if p.is_file():shutil.copy2(p,o/p.name)
 elif p.name.startswith(('trace-','buffer-','final-','final2-')) and p.name not in ['trace-web']:
  shutil.copytree(p,o/'captures'/p.name,dirs_exist_ok=True)
shutil.copytree(s/'served',o/'served',dirs_exist_ok=True)
for f in ['package.json','package-lock.json']:
 shutil.copy2(s/'runtime'/f,o/('capture-runtime-'+f))
port=json.loads((s/'server.json').read_text())['port'];m=json.loads((o/'final2-build-manifest.json').read_text());served={}
for f,h in m.items():
 b=urllib.request.urlopen(f'http://127.0.0.1:{port}/'+urllib.parse.quote(f)).read();actual=hashlib.sha256(b).hexdigest();assert actual==h,f;served[f]=actual
(o/'served-final2.json').write_text(json.dumps(served,indent=2))
expected={str(p.relative_to(o)):[c['name'] for c in json.loads(p.read_text())['checks'] if not c['pass']] for p in (o/'captures').glob('*/*/results.json')}
(o/'expected-capture-failures.json').write_text(json.dumps(expected,indent=2))
print('captured contexts',len(expected),'failures', {p:f for p,f in expected.items() if f})
