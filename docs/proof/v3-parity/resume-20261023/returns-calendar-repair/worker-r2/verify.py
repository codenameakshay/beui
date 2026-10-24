from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parent
manifest=json.loads((r/'final-input-hashes.json').read_text())
for name,entry in manifest.items():
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==entry['sha256'],name
summary=[]
for motion in ['no-preference','reduce']:
 for target in ['source','candidate']:
  d=json.loads((r/f'attempt-3/{target}-{motion}/results.json').read_text())
  states={s['name']:s for s in d['states']}
  assert len(states)==(35 if target=='candidate' else 26)
  assert not d['errors']
  assert all(c['pass'] for c in d['checks'])
  assert all(e['isTrusted'] or (e['type']=='click' and e['x']==0 and e['y']==0) for e in d['inputs'])
  # Flutter consumes Tab keydown before this document listener; trusted
  # keyup remains observable for every Tab in the unchanged capture sequence.
  assert sum(e['type']=='keyup' and e.get('key')=='Tab' and e['isTrusted'] for e in d['inputs']) == (11 if target=='candidate' else 8)
  for name in ['missing-focused','months-reinserted']:
   assert states[name]['identity']['connected'],(target,name)
  assert states['missing-focused']['identity']['sameFocused']
  for name in ['year-replaced','year-reinserted','year-removed','empty-focused']:
   assert not states[name]['identity']['connected'],(target,name)
  def focus(name):
   f=states[name]['focus'];return f['label'] or f['text']
  for name,month,year in [('replacement-next','Jan','2030'),('reinsert-next','Jan','2025'),('missing-next','Apr','2025')]:
   f=focus(name);assert month in f and year in f,(target,name,f)
  assert '+0.0%' in states['missing-next']['aria']
  assert 'Jan 2025' in states['year-reinserted']['aria']
  for name,value in [('removal-next','initial'),('removed-reinsert-next','missing'),('empty-next','initial')]:
   assert focus(name)==value,(target,name,focus(name))
  for s in d['states']:
   p=r/f'attempt-3/{target}-{motion}'/s['screenshot']['file']
   assert hashlib.sha256(p.read_bytes()).hexdigest()==s['screenshot']['sha256']
  for script in d['scripts']:
   assert hashlib.sha256((r/'served-js'/f"{script['sha256']}.js").read_bytes()).hexdigest()==script['sha256']
  if target=='candidate':
   served=manifest['candidate/example/build/web/main.dart.js']['sha256']
   assert any(s['sha256']==served for s in d['scripts'])
  f=focus('replacement-reverse')
  assert '2024' in f and ('Year' in f or 'for the year' in f), (target, f)
  assert not states['reverse-replaced']['identity']['connected']
  if target=='candidate':
   assert states['move-after']['identity']['sameFocused']
   assert states['move-after']['identity']['connected']
   assert states['move-after']['fixture']['moved']
   assert not states['move-back']['fixture']['moved']
   assert '2025 Apr' in focus('move-next')
   assert '2025 Apr' in focus('move-back')
   assert states['grid-remounted']['fixture']['gridKey']==1
   assert not states['grid-remounted']['identity']['connected']
   assert '2024 Year' in focus('remount-reverse')
   assert '2030 Jan' in focus('remount-forward')
  summary.append({'target':target,'motion':motion,'checkpoints':len(states),'pass':True})
print(json.dumps(summary,indent=2))
