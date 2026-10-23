import 'dart:convert';
import 'dart:js_interop';
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
@JS('globalThis.__fixture') external set probe(JSAny? value);
void main()=>runApp(const Fixture());
class Fixture extends StatefulWidget{const Fixture({super.key});@override State<Fixture> createState()=>_FixtureState();}
class _FixtureState extends State<Fixture>{String state='initial';Map<String,dynamic>? snapshots;
@override void initState(){super.initState();rootBundle.loadString('assets/snapshots.json').then((s)=>setState(()=>snapshots=jsonDecode(s)));}
void change(String s)=>setState(()=>state=s);
@override Widget build(BuildContext context)=>MaterialApp(theme:ThemeData(fontFamily:'Geist',extensions:[BeuiColors.light()]),home:Builder(builder:(context){final data=snapshots?[state];probe={'state':state,'snapshot':data,'disableAnimations':MediaQuery.disableAnimationsOf(context)}.jsify();return CallbackShortcuts(bindings:{for(final e in {LogicalKeyboardKey.keyI:'initial',LogicalKeyboardKey.keyB:'blank',LogicalKeyboardKey.keyR:'refresh',LogicalKeyboardKey.keyS:'shrink',LogicalKeyboardKey.keyD:'date'}.entries)SingleActivator(e.key):()=>change(e.value)},child:Scaffold(body:Center(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Fixture $state'),Row(mainAxisSize:MainAxisSize.min,children:[for(final s in ['initial','blank','refresh','shrink','date'])TextButton(onPressed:()=>change(s),child:Text(s))]),if(data!=null)BeuiHeatCalendar(weeks:data['weeks'],maxCount:10,endDate:DateTime.parse(data['endDate']+'T00:00:00Z'),values:[for(final col in data['values'])[for(final v in col)(v as num).toDouble()]],color:'#6366f1')]))));}));}
