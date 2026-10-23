from pathlib import Path
import hashlib,json,math
from PIL import Image,ImageChops
p=Path('/tmp/beui-mono-research-20261023')
s=json.loads((p/'source-measurements.json').read_text()); c=json.loads((p/'candidate-measurements.json').read_text()); d=json.loads((p/'dom-controls.json').read_text());summary=[]
for chart,strings in [('candle',['15:55','2,360.34','Vol','+0.34%']),('volume',['2,271 BTC','$65,050'])]:
 for text in strings:
  a=next(x for x in next(x for x in s if x['chart']==chart)['data'] if x['text']==text)
  b=next(x for x in next(x for x in c if x['chart']==chart)['data'] if x['text']==text)
  g=next((x for x in next(x for x in c if x['chart']=='gallery-'+chart)['data'] if x['text']==text),{})
  controls=[x for x in next(x for x in c if x['chart']=='probe')['data'] if x['text']==text and x['weight']==b['weight']]
  dom=next(x for x in d if x['text']==text and x['weight']==b['weight'] and x['family']=='Geist Mono')
  summary.append({'chart':chart,'text':text,'sourceDOMWidth':a['rect']['width'],'sourceCanvasAdvance':dom['canvasAdvance'],'actualCandidateAdvance':b['advance'],'actualGalleryAdvance':g.get('advance'),'controls':[{k:x[k] for k in ['family','advance','baseline']} for x in controls],'sourceBaseline':a['baseline'],'candidateBaseline':b['y']+b['baseline'],'sourceTop':a['rect']['y'],'candidateTop':b['y'],'sourceMinusCandidateWidth':a['rect']['width']-b['advance']})
(p/'comparison.json').write_text(json.dumps(summary,indent=2))
regions={'candle':(348,344,932,368),'volume':(348,690,932,714)};pixels=[]
for chart,box in regions.items():
 imgs=[]
 for mode in ['source','candidate']:
  im=Image.open(p/f'{mode}-{chart}.png').convert('RGB').crop(box);im.save(p/f'{mode}-{chart}-raw-crop.png');imgs.append(im)
 diff=ImageChops.difference(*imgs);n=sum(any(v for v in px) for px in diff.getdata());pixels.append({'chart':chart,'cropXYXY':box,'pixels':imgs[0].width*imgs[0].height,'nonzeroRGBPixels':n,'method':'identical integer crop coordinates; no alignment, scaling, recoloring or mask'})
(p/'crop-metrics.json').write_text(json.dumps(pixels,indent=2))
files=[p/'repo/example/lib/mono_fixture.dart',p/'repo/example/pubspec.yaml',p/'repo/example/pubspec.lock']+list((p/'candidate-exact').glob('*.js'))+list((p/'candidate-exact/assets').glob('*Manifest*'))+list((p/'candidate-exact/assets/assets/fonts').glob('*Mono*.ttf'))+list((p/'source').glob('*'))
(p/'final-inputs.json').write_text(json.dumps({str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files if f.is_file()},indent=2))
print(json.dumps({'comparison':summary,'pixels':pixels},indent=2))
