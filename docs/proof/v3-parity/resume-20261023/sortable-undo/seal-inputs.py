import pathlib,json,hashlib,shutil,subprocess
r=pathlib.Path(__file__).resolve().parent
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=[]
for name in json.loads((r/'source/metafile.json').read_text())['inputs']:
 p=(r/'source'/name).resolve(); digest=h(p);dst=r/'source-inputs'/digest;dst.parent.mkdir(exist_ok=True);shutil.copy2(p,dst);inputs.append({'original':name,'archive':str(dst.relative_to(r)),'sha256':digest})
(r/'source-inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
repo=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2');pin='a76e57c9bbc2837e96420b2610e9c82a3271bb05'
bindings={'baseHead':'1254bfa63a70298061c557616abeb9c6a67db372','sourcePin':pin,'sourceFiles':{},'candidateFiles':{},'flutterVersion':subprocess.check_output(['flutter','--version'],text=True),'ports':{'source':18159,'candidate':18160},'portCheck':'lsof -nP -iTCP:18159 -iTCP:18160 -sTCP:LISTEN returned no listeners before servers started'}
for n in ['components/motion/sortable-list.tsx','lib/ease.ts','lib/utils.ts']:
 original=subprocess.check_output(['git','-C','/tmp/beui-charts-reference-20261023','show',pin+':'+n]);assert hashlib.sha256(original).hexdigest()==h(r/'source'/n);bindings['sourceFiles'][n]=h(r/'source'/n)
for p in (r/'candidate/lib').rglob('*.dart'):
 rel=p.relative_to(r/'candidate');assert h(p)==h(repo/rel);bindings['candidateFiles'][str(rel)]=h(p)
shutil.copy2(repo/'test/motion/sortable_list_test.dart',r/'sortable_list_test.dart')
(r/'baseline-sortable_list.dart').write_bytes(subprocess.check_output(['git','-C',str(repo),'show','1254bfa63:lib/src/motion/sortable_list.dart']))
bindings['testSha256']=h(r/'sortable_list_test.dart');bindings['baselineSha256']=h(r/'baseline-sortable_list.dart');bindings['candidateMainJs']=h(r/'candidate/example/build/web/main.dart.js');bindings['sourceJs']=h(r/'source/source.js')
(r/'bindings.json').write_text(json.dumps(bindings,indent=2)+'\n')
