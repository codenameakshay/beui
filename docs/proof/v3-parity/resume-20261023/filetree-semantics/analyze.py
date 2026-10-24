from pathlib import Path
import json
r=Path(__file__).resolve().parent
names=['rest','tab-parent','expand-parent','enter-folder','expand-folder','enter-leaf','select-leaf','disabled-down','disabled-enter','disabled-space','sibling-down','end-tail','home-parent','return-folder','collapse-folder','parent-left','collapse-parent','reexpand-parent','reenter-folder','reexpand-folder','refocus-leaf','external-collapse','post-collapse-tab','post-collapse-enter']
focus=[None,'Parent','Parent','Folder','Folder','Leaf','Leaf','Disabled','Disabled','Disabled','Sibling','Tail','Parent','Folder','Folder','Parent','Parent','Parent','Folder','Folder','Leaf',None,'After','After']
changes={2:['parent'],4:['parent','folder'],14:['parent'],16:[],17:['parent'],19:['parent','folder']}
result=[]
for p in sorted((r/'attempt-2').glob('*/results.json')):
 d=json.loads(p.read_text());assert [s['name'] for s in d['states']]==names
 expanded=[];expCalls=[];checks=[]
 for i,s in enumerate(d['states']):
  if i in changes:expanded=changes[i];expCalls.append(expanded)
  if i==21:expanded=[]
  rows=['Parent']+(['Folder']+(['Leaf','Disabled','Sibling'] if 'folder' in expanded else [])+['Peer'] if 'parent' in expanded else [])+['Tail']
  f=s['fixture'];expectedCalls=[] if i<6 else ['leaf']
  actual=[x['text'] for x in s['rows']]
  for name,ok in [('visible rows',actual==rows),('expanded IDs',f['expanded']==expanded),('expansion callbacks',f['expCalls']==expCalls),('selection callbacks',f['calls']==expectedCalls),('selection value',f['value']==('none' if i<6 else 'leaf')),('motion preference',s['reduce']==(d['reducedMotion']=='reduce')==f['disableAnimations'])]:
   assert ok,(str(p),s['name'],name,s);checks.append({'state':s['name'],'check':name,'pass':ok})
  if focus[i] is not None:
   assert s['focus']['text']==focus[i],(p,s['name'],s['focus']);checks.append({'state':s['name'],'check':'native DOM focus','pass':True})
  if i==21:
   assert (s['focus']['tag']=='BODY' if d['target']=='source' else s['focus']['text']=='Parent')
  if d['target']=='source' and i in [7,8,9]:assert next(x for x in s['rows'] if x['text']=='Disabled')['disabled']=='true'
  if d['target']=='candidate':
   assert [x['text'] for x in s['rows'] if x['current']=='true']==(['Leaf'] if i>=6 and 'Leaf' in rows else [])
   if 'Disabled' in rows: assert 'aria-disabled="true"' in next(x for x in s['rows'] if x['text']=='Disabled')['html']
  selected=[x['text'] for x in s['rows'] if x['selected']=='true']
  if d['target']=='source':assert selected==(['Leaf'] if i>=6 and 'Leaf' in rows else []),(p,s['name'],selected)
 assert not [x for x in d['checks'] if not x['pass']],p
 result.append({'run':str(p.parent.relative_to(r)),'states':len(d['states']),'checks':checks,'collapseFocus':d['states'][21]['focus'],'postCollapseFocus':d['states'][22]['focus']})
assert len(result)==4
print(json.dumps(result,indent=2))
