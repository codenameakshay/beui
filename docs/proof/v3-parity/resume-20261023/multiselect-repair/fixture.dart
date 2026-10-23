import 'dart:js_interop';
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
@JS('globalThis.__fixture') external set probe(JSAny? value);
void main()=>runApp(const Fixture());
class Fixture extends StatefulWidget{const Fixture({super.key});@override State<Fixture> createState()=>_FixtureState();}
class _FixtureState extends State<Fixture>{List<String> value=['alpha','beta','gamma'];final calls=<List<String>>[];String query='';bool open=false;final reject=Uri.base.queryParameters['owner']=='reject';
@override Widget build(BuildContext context)=>MaterialApp(theme:ThemeData(fontFamily:'Geist',extensions:[BeuiColors.light()]),home:Builder(builder:(context){probe={'value':value,'calls':calls,'query':query,'open':open,'reject':reject,'disableAnimations':MediaQuery.disableAnimationsOf(context)}.jsify();return Scaffold(body:Align(alignment:Alignment.topCenter,child:Padding(padding:const EdgeInsets.only(top:100),child:SizedBox(width:480,child:Column(children:[Text('Supplemental MultiSelect ${reject?'reject':'accept'} owner'),BeuiMultiSelect(value:value,onChanged:(v)=>setState((){calls.add(v);if(!reject)value=v;}),onQueryChanged:(q)=>setState(()=>query=q),onOpenChanged:(v)=>setState(()=>open=v),items:const [BeuiMultiSelectOption(value:'alpha',label:'Alpha'),BeuiMultiSelectOption(value:'disabled',label:'Disabled',disabled:true),BeuiMultiSelectOption(value:'beta',label:'Beta'),BeuiMultiSelectOption(value:'gamma',label:'Gamma'),BeuiMultiSelectOption(value:'delta',label:'Delta')])])))));}));}
