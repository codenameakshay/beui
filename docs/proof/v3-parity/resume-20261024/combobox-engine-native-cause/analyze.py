from pathlib import Path
import json
s=Path('/tmp/beui-gallery-engine-causal-r10'); rows=[]
for p in sorted(s.glob('*-*/*/results.json')):
 d=json.loads(p.read_text());state=next(x for x in d['states'] if x['name'] in ['initial-type','filtered']); inputs=[x for x in d['inputs'] if x['type']=='input']; trace=d['trace'];first=inputs[0]; activate=next((x for x in trace if x['event']=='semantics.activate'),None)
 row={'path':str(p.relative_to(s)),'initial':state['focus']['value'],'failures':[x['name'] for x in d['checks'] if not x['pass']],'traces':len(trace),'initialInput':first}
 if activate:
  before=[x for x in inputs if x['time']<activate['time']]; replay=next(x for x in trace if x['event']=='DOM.apply'); row.update({'activation':activate,'inputsBeforeActivation':before,'replay':replay,'deliveredBeforeActivation':[x for x in trace if x['event']=='channel.update' and x['time']<activate['time']]})
 rows.append(row)
(s/'analysis.json').write_text(json.dumps(rows,indent=2));print('\n'.join(str((x['path'],x['initial'],[i['value'] for i in x.get('inputsBeforeActivation',[])])) for x in rows))
