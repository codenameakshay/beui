import 'dart:async';
import 'dart:js_interop';
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
@JS('globalThis.__fixture') external set probe(JSAny? value);
void main()=>runApp(const Fixture());
class Fixture extends StatefulWidget{const Fixture({super.key});@override State<Fixture> createState()=>_FixtureState();}
class _FixtureState extends State<Fixture>{List<String> expanded=[];String value='none';final calls=<String>[],expCalls=<List<String>>[];bool reduce=false;Timer? timer;
@override void initState(){super.initState();timer=Timer.periodic(const Duration(milliseconds:50),(_){probe={'expanded':expanded,'value':value,'calls':calls,'expCalls':expCalls,'disableAnimations':reduce,'primaryFocus':FocusManager.instance.primaryFocus?.debugLabel}.jsify();});}
@override void dispose(){timer?.cancel();super.dispose();}
@override Widget build(BuildContext context)=>MaterialApp(theme:ThemeData(fontFamily:'Geist',extensions:[BeuiColors.light()]),home:Builder(builder:(context){reduce=MediaQuery.disableAnimationsOf(context);return Scaffold(body:Center(child:SizedBox(width:480,child:Focus(onKeyEvent:(node,event){if(event is KeyDownEvent&&event.logicalKey==LogicalKeyboardKey.keyC){setState(()=>expanded=[]);return KeyEventResult.handled;}return KeyEventResult.ignored;},child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Supplemental FileTree. C externally collapses all folders.'),TextButton(onPressed:(){},child:const Text('Before')),BeuiFileTree(value:value,expandedIds:expanded,onChanged:(v)=>setState((){value=v;calls.add(v);}),onExpandedChanged:(v)=>setState((){expanded=v;expCalls.add(v);}),children:const [BeuiFileTreeFolder(value:'parent',name:'Parent',children:[BeuiFileTreeFolder(value:'folder',name:'Folder',children:[BeuiFileTreeFile(value:'leaf',name:'Leaf'),BeuiFileTreeFile(value:'disabled',name:'Disabled',disabled:true),BeuiFileTreeFile(value:'sibling',name:'Sibling')]),BeuiFileTreeFile(value:'peer',name:'Peer')]),BeuiFileTreeFile(value:'tail',name:'Tail')]),TextButton(onPressed:(){},child:const Text('After'))])))));}));}
