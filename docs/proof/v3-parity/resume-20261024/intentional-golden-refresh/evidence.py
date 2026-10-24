import pathlib,json,hashlib,subprocess,shutil
from PIL import Image,ImageOps,ImageDraw
from run import ROOT,OUT,WORK,SDK,rows
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if __name__=='__main__':
 import sys
 if sys.argv[1]=='environment':
  env={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'os':subprocess.check_output(['sw_vers'],text=True),'uname':subprocess.check_output(['uname','-a'],text=True),'sdk':str(SDK),'version':json.loads((OUT/'version.jsonl').read_text()),'fonts':{str(p.relative_to(SDK)):sha(p) for p in SDK.glob('bin/cache/artifacts/**/*.ttf')},'inputs':{str(p.relative_to(ROOT)):sha(p) for folder in ['lib','test','example/lib','example/test'] for p in (ROOT/folder).rglob('*.dart')},'all_original_goldens':{str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'test').rglob('goldens/*.png')}}
  (OUT/'environment.json').write_text(json.dumps(env,indent=2))
  for name in ['pubspec.yaml','pubspec.lock','.dart_tool/package_config.json','test/flutter_test_config.dart','test/support.dart']:
   p=WORK/name
   if p.exists():shutil.copy2(p,OUT/name.replace('/','-'))
  with (OUT/'dependency-tree.json').open('w') as f:subprocess.run([str(SDK/'bin/flutter'),'pub','deps','--json'],cwd=WORK,stdout=f,check=True)
 elif sys.argv[1]=='sheets':
  records=json.loads((OUT/'before.json').read_text());selected=[]
  for r in records:
   p=WORK/r['golden'];r['after_sha256']=sha(p);r['after_dimensions']=Image.open(p).size
   if r['classification']=='intentional visual change':
    selected.append(r);dst=OUT/'review'/pathlib.Path(r['golden']).name;dst.parent.mkdir(exist_ok=True);shutil.copy2(p,dst)
  (OUT/'manifest.json').write_text(json.dumps(records,indent=2))
  for i in range(0,len(selected),5):
   sheet=Image.new('RGB',(1200,5*320),'#ddd');d=ImageDraw.Draw(sheet)
   for j,r in enumerate(selected[i:i+5]):
    d.text((10,j*320+5),f"{r['number']:02} {pathlib.Path(r['golden']).name} | before / after",fill='black')
    for k,base in enumerate([ROOT,WORK]):
     im=Image.open(base/r['golden']).convert('RGB');im.thumbnail((580,285));sheet.paste(im,(k*600+(600-im.width)//2,j*320+30))
   sheet.save(OUT/f'contact-sheet-{i//5+1}.png')
