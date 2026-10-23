from pathlib import Path
import subprocess,shutil
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261024/scheduler-copy';t=Path('/tmp/beui-scheduler-copy-20261024');t.mkdir(exist_ok=True)
with open(t/'candidate.tar','wb') as f: subprocess.run(['git','archive','HEAD','lib','assets','shaders','pubspec.yaml','example'],stdout=f,check=True)
c=t/'candidate';c.mkdir(exist_ok=True);subprocess.run(['tar','-xf',str(t/'candidate.tar'),'-C',str(c)],check=True)
shutil.copy(r/'lib/src/motion/availability_scheduler/copy_menu.dart',c/'lib/src/motion/availability_scheduler/copy_menu.dart')
old=r/'docs/proof/v3-parity/resume-20261023/multiselect-native'
(o/'build_source.mjs').write_text((old/'build_source.mjs').read_text().replace('resume-20261023/multiselect-native','resume-20261024/scheduler-copy'))
(o/'source.css').write_text((old/'source.css').read_text().replace('multi-select','availability-scheduler')+"\n:root{--primary:#171717;--primary-foreground:white;--popover:#fff;}\n@theme inline{--color-primary:var(--primary);--color-primary-foreground:var(--primary-foreground);--color-popover:var(--popover);}\n@source '/tmp/beui-charts-reference-20261023/components/motion/checkbox.tsx';")
(o/'source.tsx').write_text("""import React,{useState} from 'react';import{createRoot}from'react-dom/client';import{AvailabilityScheduler}from '@/components/motion/availability-scheduler';
const days=['mon','tue','wed','thu','fri','sat','sun'];
const initial=Object.fromEntries(days.map(d=>[d,{enabled:d!=='tue'&&d!=='sat',ranges:[{id:d+'-fixed',start:d==='mon'?'08:30':'10:00',end:d==='mon'?'16:30':'12:00'}]}]));
function App(){const[value,set]=useState(initial),[calls,record]=useState([]);const reject=new URLSearchParams(location.search).get('owner')==='reject';globalThis.__fixture={value,calls,reject};return <div style={{width:600}}><AvailabilityScheduler value={value} onChange={v=>{record(c=>[...c,v]);if(!reject)set(v)}}/></div>}createRoot(document.getElementById('root')).render(<App/>);""")
(o/'fixture.dart').write_text("""import 'dart:js_interop';
import 'package:beui/beui.dart';import 'package:flutter/material.dart';
@JS('globalThis.__fixture') external set probe(JSAny? value);
void main()=>runApp(const Fixture());
class Fixture extends StatefulWidget{const Fixture({super.key});@override State<Fixture> createState()=>_FixtureState();}
class _FixtureState extends State<Fixture>{
BeuiWeekAvailability value={for(final d in BeuiDayKey.values)d:BeuiDayAvailability(enabled:d!=BeuiDayKey.tue&&d!=BeuiDayKey.sat,ranges:[BeuiTimeRange(id:'${d.name}-fixed',start:d==BeuiDayKey.mon?'08:30':'10:00',end:d==BeuiDayKey.mon?'16:30':'12:00')])};
final calls=<Object>[];final reject=Uri.base.queryParameters['owner']=='reject';
Object data(BeuiWeekAvailability w)=>{for(final e in w.entries)e.key.name:{'enabled':e.value.enabled,'ranges':[for(final r in e.value.ranges){'id':r.id,'start':r.start,'end':r.end}]}};
@override Widget build(BuildContext context){probe={'value':data(value),'calls':calls,'reject':reject}.jsify();return MaterialApp(theme:ThemeData(fontFamily:'Geist',extensions:[BeuiColors.light()]),home:Scaffold(body:Center(child:SingleChildScrollView(child:BeuiAvailabilityScheduler(value:value,onChanged:(v)=>setState((){calls.add(data(v));if(!reject)value=v;}))))));}}
""")
shutil.copy(o/'fixture.dart',c/'example/lib/main.dart')
