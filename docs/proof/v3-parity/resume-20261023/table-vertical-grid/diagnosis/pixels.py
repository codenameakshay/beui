import json
from PIL import Image
result={}
for side in ['source','after']:
 im=Image.open('/tmp/beui-table-vertical-research/'+side+'-no-preference.png').convert('RGB')
 r={'rules_at_x700':[(y,im.getpixel((700,y))) for y in list(range(91,96))+list(range(143,148))],'ink_bounds':{}}
 for name,(x0,x1,y0,y1) in {'header':(425,464,50,84),'name1':(401,470,100,139),'email1':(514,660,100,139),'role1':(709,750,100,139)}.items():
  ys=[y for y in range(y0,y1) if any((max(im.getpixel((x,y)))-min(im.getpixel((x,y)))<8 and min(im.getpixel((x,y)))<180) for x in range(x0,x1))]
  r['ink_bounds'][name]={'first_row':min(ys),'last_row':max(ys),'roi':[x0,x1,y0,y1]}
 result[side]=r
open('/tmp/beui-table-vertical-research/pixels.json','w').write(json.dumps(result,indent=2))
