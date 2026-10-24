import pathlib,json,hashlib
r=pathlib.Path(__file__).parent
summary=[]
for p in sorted(r.iterdir()):
 if not p.is_dir() or not (p/'trace.json').exists(): continue
 states=json.loads((p/'states.json').read_text()); traces=json.loads((p/'trace.json').read_text())
 moves=[x for row in traces for x in row if x['type']=='production-active-move']
 real=[x for x in moves if x['to'] not in [x['from'],x['from']+1]]
 assert all(x['retained'] and x['exactOrder'] for x in moves)
 served=[x for row in json.loads((p/'served.json').read_text()) for x in row if x['url'].endswith('/main.dart.js')]
 assert served and all(x['sha256']==hashlib.sha256((r/'bump-web/main.dart.js').read_bytes()).hexdigest() for x in served)
 events=json.loads(next(p.glob('*events.json')).read_text())['events']
 assert all(x['isTrusted'] for x in events if x['type'] in ['keydown','pointerdown'])
 assert len(states)==21
 assert all(x['browserReducedMotion']==(x['reducedMotion']=='reduce') for x in states)
 summary.append(dict(run=p.name,states=len(states),moves=moves,actualReorders=len(real),servedMain=served,trustedInput=True))
(r/'native-summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps([{'run':x['run'],'states':x['states'],'actualReorders':x['actualReorders']} for x in summary],indent=2))
