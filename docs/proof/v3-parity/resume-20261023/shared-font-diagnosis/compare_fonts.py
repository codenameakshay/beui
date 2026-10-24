from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.recordingPen import RecordingPen
from pathlib import Path
import json,hashlib
out=[]
for family,base,weights in [('Geist','geist-live.woff2',[400,500,600,700]),('GeistMono','geist-mono-live.woff2',[400,500])]:
 for w in weights:
  name={400:'Regular',500:'Medium',600:'SemiBold',700:'Bold'}[w]
  cp=Path('example/assets/fonts')/f'{family}-{name}.ttf';sp=Path('docs/proof/v3-parity/charts/round4-bump/source-fonts')/base
  c=TTFont(cp);s=instantiateVariableFont(TTFont(sp),{'wght':w},inplace=False)
  cm=c.getBestCmap();sm=s.getBestCmap(); chars=sorted(set(cm)&set(sm));diff=[];width=[]
  for ch in chars:
   a=RecordingPen();b=RecordingPen();c.getGlyphSet()[cm[ch]].draw(a);s.getGlyphSet()[sm[ch]].draw(b)
   if a.value!=b.value:diff.append(ch)
   if c['hmtx'][cm[ch]]!=s['hmtx'][sm[ch]]:width.append(ch)
  out.append(dict(family=family,weight=w,candidate=str(cp),source=str(sp),candidate_sha256=hashlib.sha256(cp.read_bytes()).hexdigest(),source_sha256=hashlib.sha256(sp.read_bytes()).hexdigest(),shared_glyphs=len(chars),outline_differences=len(diff),metric_differences=len(width),ascii_outline_differences=[chr(x) for x in diff if 32<=x<127],ascii_metric_differences=[chr(x) for x in width if 32<=x<127],zero_advance=c['hmtx'][cm[48]][0],unitsPerEm=c['head'].unitsPerEm))
Path('/tmp/beui-shared-font-diagnosis-20261023/font-comparison.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out,indent=2))
