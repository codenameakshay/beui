from PIL import Image
import json
from pathlib import Path
p=Path('/tmp/beui-table-raster-research-20261023');rows=json.loads((p/'faithful.json').read_text())
for r in rows:
 im=Image.open(p/(r['id']+'.png')).convert('RGB');r['ink']={}
 for threshold in [1,16,64,128]:
  xy=[(x,y) for y in range(100) for x in range(200) if 255-min(im.getpixel((x,y)))>=threshold]
  r['ink'][str(threshold)]=[min(x for x,y in xy),min(y for x,y in xy),max(x for x,y in xy),max(y for x,y in xy)] if xy else None
(p/'faithful-bounds.json').write_text(json.dumps(rows,indent=2))
for r in rows:
 if r['weight']==500 and r['baseline']==40.5:print(r['id'],r['data'],r['ink'])
