import pathlib,json
from PIL import Image,ImageChops
p=pathlib.Path('docs/proof/v3-parity/resume-20261024/final-golden-triage');rows=json.loads((p/'history.json').read_text())
def diff(a,b):
 a=Image.open(a).convert('RGBA');b=Image.open(b).convert('RGBA')
 if a.size!=b.size:return {'size_a':a.size,'size_b':b.size,'pixels':None}
 return {'pixels':sum(x!=(0,0,0,0) for x in ImageChops.difference(a,b).getdata()),'size':a.size}
for r in rows:
 name=pathlib.Path(r['golden']).stem;folder=pathlib.Path(r['file']).parent/'failures';date=r['date']
 prefix='author-' if date.startswith('2026-10') else 'author-lucide131-' if date.startswith('2026-08-18') else 'author-pinned-'
 author=p/(prefix+r['author_commit'][:9])/folder/f'{name}_testImage.png'
 if not author.exists():author=pathlib.Path(r['golden'])
 current=p/'current-3444'/folder/f'{name}_testImage.png'
 if not current.exists():current=pathlib.Path(r['golden'])
 r['author_vs_current3444']=diff(author,current)
 r['author_render_vs_golden']=diff(author,pathlib.Path(r['golden']))
 r['current3444_vs_golden']=diff(current,pathlib.Path(r['golden']))
 print(name, r['author_render_vs_golden']['pixels'],r['author_vs_current3444']['pixels'],r['current3444_vs_golden']['pixels'])
(p/'comparison-controls.json').write_text(json.dumps(rows,indent=2))
