import pathlib,hashlib,json,subprocess,shutil
r=pathlib.Path(__file__).resolve().parent
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pin='a76e57c9bbc2837e96420b2610e9c82a3271bb05'
b={'sourcePin':pin,'ports':{'source':18165,'candidate':18166},'portCheck':'lsof found no listeners before launch; owned server PIDs 35954 and 35958','sourceFiles':{},'candidateFiles':{},'testSha256':h(r/'sortable_list_test.dart'),'baselineComponent':h(r/'baseline-sortable_list.dart'),'component':h(r/'candidate/lib/src/motion/sortable_list.dart'),'baselineMainJs':h(r/'baseline-web/main.dart.js'),'candidateMainJs':h(r/'candidate/example/build/web/main.dart.js'),'sourceJs':h(r/'source/source.js'),'baselineFixture':h(r/'baseline-fixture.dart'),'fixture':h(r/'candidate/example/lib/main.dart'),'flutterVersion':(r/'flutter-version.txt').read_text()}
assert b['baselineComponent']=='2cd852ea3cbf4e377708c1043e6eadca06e12f20735ffdb06ef194c9850736af'
for name in ['components/motion/sortable-list.tsx','lib/ease.ts','lib/utils.ts']:
 original=subprocess.check_output(['git','-C','/tmp/beui-charts-reference-20261023','show',pin+':'+name]);assert hashlib.sha256(original).hexdigest()==h(r/'source'/name);b['sourceFiles'][name]=h(r/'source'/name)
for p in (r/'candidate/lib').rglob('*.dart'):b['candidateFiles'][str(p.relative_to(r/'candidate'))]=h(p)
repo=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2')
assert b['component']==h(repo/'lib/src/motion/sortable_list.dart');assert b['testSha256']==h(repo/'test/motion/sortable_list_test.dart')
(r/'bindings.json').write_text(json.dumps(b,indent=2)+'\n')
