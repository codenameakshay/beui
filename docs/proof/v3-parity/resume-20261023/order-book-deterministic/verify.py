"""Offline verification of retained originals; requires Python 3 and ffprobe."""
from pathlib import Path
import hashlib,json,tarfile,subprocess,sys
root=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
checks=[]
def check(label,condition):
 checks.append({'check':label,'pass':bool(condition)})
 if not condition: print('FAIL',label)
def read(p):return json.loads((root/p).read_text())
seal=read('archive-sha256.json')
for name,digest in seal.items():check('integrity '+name,sha((root/name).read_bytes())==digest)
for archive,entries in [('candidate-input-originals.tar.gz',read('candidate-effective-inputs.json')),('source-input-originals.tar.gz',{e['path'].lstrip('/'):e['sha256'] for e in read('source-inputs.json')['inputs']})]:
 with tarfile.open(root/archive) as tar:
  for name,digest in entries.items():
   f=tar.extractfile(name);check('input '+name,f is not None and sha(f.read())==digest)
snapshots=read('snapshots.json'); results=[]
expect={
 'hover-ask-a':('ask',101),'select-ask-a':('ask',101),
 'hover-ask-b':('ask',102),'select-ask-b':('ask',102),
 'hover-bid-a':('bid',99),'select-bid-a':('bid',99),
 'hover-bid-b':('bid',98),'select-bid-b':('bid',98),
 'tab-ask-a':('ask',101),'enter-ask-a':('ask',101),'tab-bid-a':('bid',99),'tab-bid-b':('bid',98),
 'reverse-bid-a':('bid',99),'ignored-chart-arrows':('bid',99),'reorder-focused':('bid',99),'step-focused':('bid',99),
 'before-remove-bids':('bid',98),'before-remove-asks':('ask',101),
 'restore-hover':('ask',102),'bids-only-hover':('bid',98),'asks-only-hover':('ask',102),
}
focus={'tab-ask-a':101,'enter-ask-a':101,'tab-bid-a':99,'tab-bid-b':98,'reverse-bid-a':99,'ignored-chart-arrows':99,'reorder-focused':99,'step-focused':99,'before-remove-bids':98,'before-remove-asks':101}
empty=['rest','paused-hold','exit-ask-a','exit-ask-b','exit-bid-a','exit-bid-b','empty-focused','remove-focused-bid','remove-focused-ask','empty','bids-only','asks-only','restored']
for motion in ['no-preference','reduce']:
 pair=[]
 for target in ['source','candidate']:
  directory=f'attempt-2/{target}-{motion}'; d=read(directory+'/results.json'); states={s['name']:s for s in d['states']};pair.append(states)
  check(directory+' capture assertions',all(c['pass'] for c in d['checks']))
  check(directory+' complete states',set(expect)|set(empty)==set(states))
  for name,s in states.items():
   check(directory+'/'+name+' snapshot',s['fixture']['snapshot']==snapshots[s['fixture']['state']])
   check(directory+'/'+name+' motion',s['fixture']['disableAnimations']==s['reduce']==(motion=='reduce'))
   check(directory+'/'+name+' desktop hover',s['hover'])
   check(directory+'/'+name+' screenshot',sha((root/directory/s['screenshot']['file']).read_bytes())==s['screenshot']['sha256'])
  check(directory+' paused unchanged',states['rest']['fixture']['snapshot']==states['paused-hold']['fixture']['snapshot'] and states['paused-hold']['fixture']['paused'])
  for name,(side,price) in expect.items():
   s=states[name]; rows=s['fixture']['snapshot'][side+'s']; selected=[r for r in rows if r['price']>=price] if side=='bid' else [r for r in rows if r['price']<=price];qty=sum(r['size'] for r in selected);quote=sum(r['size']*r['price'] for r in selected)
   check(directory+'/'+name+' exact cumulative quantity and quote',f'{qty} BTC · {quote:,.2f} USD' in s['aria'])
   check(directory+'/'+name+' weighted average',f'{quote/qty:,.2f}' in s['aria'] and 'Avg' in s['aria'])
   if name.startswith('select-') or name=='enter-ask-a':
    v=s['fixture']['selections'][-1];check(directory+'/'+name+' actual callback',v['side']==side and v['price']==price and v['total']==qty)
  for name,price in focus.items():check(directory+'/'+name+' actual focus',states[name]['focus']['text']==f'{price:.2f}')
  for name in empty:check(directory+'/'+name+' no stale readout','Hover a level' in states[name]['aria'] and 'Avg' not in states[name]['aria'])
  for name in ['empty-focused','empty']:check(directory+'/'+name+' both sides empty',all(t in states[name]['aria'] for t in ['No bids','No asks','Spread unavailable']))
  for name,missing in [('remove-focused-bid','bids'),('remove-focused-ask','asks'),('bids-only','asks'),('asks-only','bids')]:check(directory+'/'+name+' missing side',f'No {missing}' in states[name]['aria'] and 'Spread unavailable' in states[name]['aria'])
  inputs=d['inputs'];synthetic=[e for e in inputs if not e['isTrusted']];check(directory+' only bootstrap synthetic',all(e['type']=='click' and e.get('x')==0 and e.get('y')==0 for e in synthetic));check(directory+' native clicks and keys',all(any(e['type']==t and e['isTrusted'] for e in inputs) for t in ['pointerdown','pointerup','keydown','keyup']))
  for script in d['scripts']:check(directory+' served JS '+script['sha256'],sha((root/'served-js'/f"{script['sha256']}.js").read_bytes())==script['sha256'])
  for f in d['frames']:check(directory+' original '+f['file'],sha((root/directory/f['file']).read_bytes())==f['sha256'])
  timestamps=[f['metadata']['timestamp'] for f in d['frames']];check(directory+' strictly increasing original timestamps',all(b>a for a,b in zip(timestamps,timestamps[1:])))
  count=subprocess.check_output(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(root/directory/'capture.mp4')],text=True).strip();check(directory+' video frame count',int(count)==len(d['frames']))
  results.append({'target':target,'motion':motion,'states':len(states),'frames':len(timestamps),'measuredFps':(len(timestamps)-1)/(timestamps[-1]-timestamps[0]),'maxGapMs':max(b-a for a,b in zip(timestamps,timestamps[1:]))*1000})
 for name in expect:check(motion+'/'+name+' source candidate snapshots equal',pair[0][name]['fixture']['snapshot']==pair[1][name]['fixture']['snapshot'])
report={'checks':len(checks),'failures':[c for c in checks if not c['pass']],'sessions':results,'verdict':'PASS' if all(c['pass'] for c in checks) else 'FAIL','limits':['No exact pixel certification','No native60 certification','No full demo timer equivalence','No screen reader or non-Chromium certification']}
print(json.dumps(report,indent=2));sys.exit(0 if report['verdict']=='PASS' else 1)
