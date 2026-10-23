from pathlib import Path
import subprocess,shutil,hashlib,json
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261023/filetree-native';t=Path('/tmp/beui-filetree-native-20261024');t.mkdir(exist_ok=True);(t/'candidate').mkdir(exist_ok=True)
with (t/'candidate.tar').open('wb') as f:subprocess.run(['git','archive','1254bfa63','lib','assets','shaders','pubspec.yaml','example'],stdout=f,check=True)
subprocess.run(['tar','-xf',str(t/'candidate.tar'),'-C',str(t/'candidate')],check=True)
f='lib/src/motion/file_tree.dart';h=lambda b:hashlib.sha256(b).hexdigest();pin=subprocess.check_output(['git','show','1254bfa63:'+f]);assert pin==(t/'candidate'/f).read_bytes()==(r/f).read_bytes()
s=Path('/tmp/beui-charts-reference-20261023');sf='components/motion/file-tree.tsx';assert (s/sf).read_bytes()==subprocess.check_output(['git','-C',str(s),'show','a76e57c9:'+sf])
(o/'identity.json').write_text(json.dumps({'candidate':'1254bfa63a70298061c557616abeb9c6a67db372','candidateFileTreeSha256':h(pin),'source':'a76e57c9bbc2837e96420b2610e9c82a3271bb05','sourceFileTreeSha256':h((s/sf).read_bytes())},indent=2))
old=o.parent/'multiselect-native';(o/'build_source.mjs').write_text((old/'build_source.mjs').read_text().replace('multiselect-native','filetree-native').replace('/tmp/beui-filetree-native-20261023/deps','/tmp/beui-multiselect-native-20261023/deps'))
(o/'source.css').write_text((old/'source.css').read_text().replace('multi-select','file-tree'))
shutil.copy('/tmp/setup-filetree.py',o/'setup.py')
