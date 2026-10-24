from pathlib import Path
import shutil,json,hashlib,subprocess
s=Path('/tmp/beui-gallery-engine-causal-r10'); repo=Path.cwd();sdk=Path('/Users/codenameakshay/fvm/default').resolve(); out=repo/'docs/proof/v3-parity/resume-20261024/combobox-engine-native-cause'
def cp(a,b):
 shutil.copytree(a,b,ignore=shutil.ignore_patterns('.git'))
cp(sdk/'bin',s/'sdk/bin');cp(sdk/'packages',s/'sdk/packages');
for n in ['version','pubspec.yaml','pubspec.lock']:
 if (sdk/n).exists():shutil.copy2(sdk/n,s/'sdk'/n)
cp(repo/'docs/proof/v3-parity/resume-20261024/combobox-rapid-input/final2-inputs',s/'gallery')
for base in ['lib','example/lib']:
 shutil.rmtree(s/'gallery'/base);cp(repo/base,s/'gallery'/base)
manifest={str(p.relative_to(s/'gallery')):hashlib.sha256(p.read_bytes()).hexdigest() for p in (s/'gallery').rglob('*') if p.is_file()}
(out/'copied-inputs.json').write_text(json.dumps(manifest,indent=2));cp(s/'gallery',out/'inputs')
# Copy exact resolved package roots so all compiler/tool writes remain isolated.
for config in [s/'gallery/.dart_tool/package_config.json',s/'gallery/example/.dart_tool/package_config.json']:
 d=json.loads(config.read_text())
 for p in d['packages']:
  u=p['rootUri']
  if u.startswith('file:'):
   src=Path(u.removeprefix('file://'));dest=s/'deps'/p['name']
   if '/packages/' in str(src) and str(src).startswith(str(sdk)):dest=s/'sdk/packages'/p['name']
   elif not dest.exists():cp(src,dest)
   p['rootUri']=dest.as_uri()
 config.write_text(json.dumps(d,indent=2))
(s/'empty-packages.json').write_text('{"configVersion":2,"packages":[]}')
(out/'provision.json').write_text(json.dumps({'sdk':str(sdk),'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'combobox':manifest['lib/src/motion/combobox.dart']},indent=2))
