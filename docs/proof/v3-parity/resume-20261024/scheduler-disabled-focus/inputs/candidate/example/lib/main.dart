import 'dart:js_interop';
import 'package:beui/beui.dart';import 'package:flutter/material.dart';
@JS('globalThis.__fixture') external set probe(JSAny? value);
void main()=>runApp(const Fixture());
class Fixture extends StatefulWidget{const Fixture({super.key});@override State<Fixture> createState()=>_FixtureState();}
class _FixtureState extends State<Fixture>{
BeuiWeekAvailability value={for(final d in BeuiDayKey.values)d:BeuiDayAvailability(enabled:d!=BeuiDayKey.tue&&d!=BeuiDayKey.sat,ranges:[BeuiTimeRange(id:'${d.name}-fixed',start:d==BeuiDayKey.mon?'08:30':'10:00',end:d==BeuiDayKey.mon?'16:30':'12:00')])};
final calls=<Object>[];final reject=Uri.base.queryParameters['owner']=='reject';
Object data(BeuiWeekAvailability w)=>{for(final e in w.entries)e.key.name:{'enabled':e.value.enabled,'ranges':[for(final r in e.value.ranges){'id':r.id,'start':r.start,'end':r.end}]}};
@override Widget build(BuildContext context){probe={'value':data(value),'calls':calls,'reject':reject}.jsify();return MaterialApp(theme:ThemeData(fontFamily:'Geist',extensions:[BeuiColors.light()]),home:Scaffold(body:Center(child:SingleChildScrollView(child:BeuiAvailabilityScheduler(value:value,onChanged:(v)=>setState((){calls.add(data(v));if(!reject)value=v;}))))));}}
