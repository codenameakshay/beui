import pathlib,json,hashlib,collections
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[4]
BASE=ROOT/'docs/proof/v3-parity/resume-20261023/components-integration-20261024'
def parse(path):
 events=[]; nonprotocol=0
 for line in path.read_text().splitlines():
  try: e=json.loads(line)
  except ValueError: nonprotocol+=1; continue
  if isinstance(e,dict) and 'type' in e: events.append(e)
  else: nonprotocol+=1
 suites={e['suite']['id']:e['suite']['path'] for e in events if e['type']=='suite'}
 tests={e['test']['id']:e['test'] for e in events if e['type']=='testStart'}
 failures=[]; passes=0; skipped=0
 for e in events:
  if e['type']!='testDone' or e.get('hidden'): continue
  if e.get('skipped'): skipped+=1
  elif e['result']=='success': passes+=1
  else:
   t=tests[e['testID']]; path=suites[t['suiteID']].split('/test/',1)[-1]
   failures.append(path+': '+t['name'])
 return {'passes':passes,'skipped':skipped,'failures':sorted(failures),'done':[e for e in events if e['type']=='done'],'nonprotocol_lines':nonprotocol}
summary={}
for name in ['root','gallery']:
 old=parse(BASE/f'beui-components-integration-{name}-20261024.jsonl'); new=parse(OUT/f'{name}.jsonl')
 summary[name]={'baseline':old,'current':new,'new_failures':sorted((collections.Counter(new['failures'])-collections.Counter(old['failures'])).elements()),'removed_failures':sorted((collections.Counter(old['failures'])-collections.Counter(new['failures'])).elements()),'baseline_log_sha256':hashlib.sha256((BASE/f'beui-components-integration-{name}-20261024.jsonl').read_bytes()).hexdigest()}
before=json.loads((OUT/'before.json').read_text()); after=json.loads((OUT/'after.json').read_text())
summary['head_before']=before['head']; summary['head_after']=after['head']
summary['six_files_unchanged']=before['files']==after['files']
summary['all_scanned_inputs_unchanged']=before['inputs']==after['inputs']
summary['scanned_input_count']=len(before['inputs'])
(OUT/'comparison.json').write_text(json.dumps(summary,indent=2)+'\n')
for k in ['root','gallery']:
 d=summary[k]; print(k,'passes',d['current']['passes'],'failures',len(d['current']['failures']),'new',len(d['new_failures']),'removed',len(d['removed_failures']))
print({k:v for k,v in summary.items() if k not in ['root','gallery']})
