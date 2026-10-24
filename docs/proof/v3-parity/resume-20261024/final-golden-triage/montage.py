from PIL import Image,ImageDraw
import pathlib,json,shutil
root=pathlib.Path.cwd();out=root/'docs/proof/v3-parity/resume-20261024/final-golden-triage'; rows=json.loads((out/'history.json').read_text())
for label,folder in [('current-3444','current'),('current-3471','current-3471')]:
 src=pathlib.Path('/tmp/beui-final-golden-triage')/folder
 shutil.copy2(src/'pubspec.lock',out/f'{label}-pubspec.lock')
 for f in src.glob('test/**/failures/*.png'):
  d=out/label/f.relative_to(src);d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,d)
for k in range(7):
 canvas=Image.new('RGB',(1200,8*225),'#dddddd');d=ImageDraw.Draw(canvas)
 for j,r in enumerate(rows[k*8:(k+1)*8]):
  name=pathlib.Path(r['golden']).stem;d.text((5,j*225+2),f'{k*8+j+1}. {name}   ORIGINAL (left) / CURRENT 3.47.1 (right)',fill='black')
  f=root/'docs/proof/v3-parity/resume-20261024/components-integration/golden-failure-feedback'/pathlib.Path(r['file']).parent/'failures'
  for x,kind in [(0,'masterImage'),(600,'testImage')]:
   im=Image.open(f/f'{name}_{kind}.png').convert('RGB');im.thumbnail((590,200));canvas.paste(im,(x,j*225+22))
 canvas.save(out/f'visual-sheet-{k+1}.png')
