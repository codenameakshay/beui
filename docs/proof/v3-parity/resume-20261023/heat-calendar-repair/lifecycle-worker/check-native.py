import json,pathlib
root=pathlib.Path('/tmp/heat-calendar-continuation')
results=[]
for p in sorted((root/'native-final').glob('*/results.json')):
 d=json.loads(p.read_text()); states={s['name']:s for s in d['states']}; candidate=d['target']=='candidate'
 def focus(name):
  f=states[name]['focus'];return f['label'] or f['text']
 removed=states['future-removal-focused'];following=states['future-removal-next'];events=following['inputs'][len(removed['inputs']):]
 checks={
 'no_immediate_cell_or_legend_focus':removed['focus']['tag']==('FLUTTER-VIEW' if candidate else 'BODY'),
 'next_forward_tab_legend0':focus('future-removal-next')==('Filter' if candidate else 'Show')+' activity level 0',
 'no_intermediate_day_focus':not any(e['type']=='focusin' and 'commits on' in (e.get('label') or e.get('text') or '') for e in events),
 'reverse_tab_final_valid_day':focus('reverse-next')=='0 commits on Mon, Oct 19',
 'external_click_focus':focus('external-focused')=='date',
 'external_focus_cancels_continuation':focus('external-reverse')=='shrink',
 'new_anchor_click_focus':focus('new-anchor')=='0 commits on Mon, Oct 5',
 'next_click_focus_oct6':focus('new-anchor-locked')=='2 commits on Tue, Oct 6',
 'trusted_inputs':all(e['isTrusted'] or e['type']=='click' and e.get('x')==0 and e.get('y')==0 for e in d['inputs']),
 'no_page_errors':not d['errors'],
 'capture_sequence_integrity':all(c['pass'] for c in d['checks']),
 }
 results.append({'target':d['target'],'motion':d['reducedMotion'],'checks':checks,'pass':all(checks.values()),'visual_selection_evidence':'new-anchor-locked.png shows 2 commits Oct 5 - Oct 6 2 days; native Flutter ARIA omits selected state'})
(root/'native-checks.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2));assert len(results)==4;assert all(r['pass'] for r in results)
