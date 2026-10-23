from pathlib import Path
import json
r=Path(__file__).resolve().parent
checks=[]
def ck(run,name,passed,actual):checks.append(dict(run=run,name=name,pass_=passed,actual=actual))
for p in sorted((r/'attempt-4').glob('*/results.json')):
 d=json.loads(p.read_text());run=p.parent.name;states={s['name']:s for s in d['states']}
 a=states['pointer-remove-alpha'];s=states['disabled-pointer']
 for field in ['value','calls','query']:ck(run,'disabled pointer preserves '+field,s['fixture'][field]==a['fixture'][field],s['fixture'][field])
 ck(run,'disabled pointer preserves chips',s['chips']==a['chips'],s['chips'])
 ck(run,'disabled pointer popup remains open',s['fixture']['open'] and ('Options' in s['aria'] or s['popup']),s['aria'])
 ck(run,'disabled pointer actual empty query',all(x['value']=='' for x in s['fields']),s['fields'])
 ck(run,'disabled pointer native focus observation',s['focus']['tag']==('BODY' if d['target']=='source' else 'FLT-SEMANTICS'),s['focus'])
 if 'closed-pointer-alpha' in states:
  before=states['closed-before-pointer'];s=states['closed-pointer-alpha'];payload=[v for v in before['fixture']['value'] if v!='alpha'];expected=before['fixture']['calls']+[payload]
  ck(run,'closed pointer exact callback',s['fixture']['calls']==expected,s['fixture']['calls'])
  value=before['fixture']['value'] if d['owner']=='reject' else payload
  ck(run,'closed pointer owner result',s['fixture']['value']==value,s['fixture']['value'])
  ck(run,'closed pointer rendered chips',sorted(s['chips'])==sorted('Remove '+v.title() for v in value),s['chips'])
  ck(run,'closed pointer actual query',all(f['value']=='' for f in s['fields']) and s['fixture']['query']=='',s['fields'])
  ck(run,'closed pointer source focus expectation',s['focus']['tag']=='INPUT',s['focus'])
  ck(run,'closed pointer source popup expectation',s['fixture']['open'],s['fixture']['open'])
print(json.dumps({'checks':checks,'failures':[c for c in checks if not c['pass_']]},indent=2))
