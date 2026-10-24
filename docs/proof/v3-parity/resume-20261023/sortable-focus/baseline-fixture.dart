import 'dart:js_interop';
import 'package:beui/src/motion/sortable_list.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
@JS('globalThis.__fixture') external set probe(JSAny? value);
@JS('globalThis.__flutterFocus') external set focusProbe(JSFunction value);
void main(){focusProbe=(() {final node=FocusManager.instance.primaryFocus;String? handle;node?.context?.visitAncestorElements((e){if(e.widget is IconButton){handle=(e.widget as IconButton).tooltip;return false;}return true;});return {'node':node==null?null:identityHashCode(node),'handle':handle,'primary':node?.hasPrimaryFocus,'attached':node?.context!=null}.jsify();}).toJS;WidgetsFlutterBinding.ensureInitialized().ensureSemantics();runApp(const Fixture());}
class Fixture extends StatefulWidget { const Fixture({super.key}); @override State<Fixture> createState()=>_FixtureState(); }
class _FixtureState extends State<Fixture>{
 final mode=Uri.base.queryParameters['mode']??'reject';
 List<String> items=['A','B','C']; final calls=<List<String>>[]; bool disabled=false;
 @override void initState(){super.initState();disabled=mode=='disabled';}
 @override Widget build(BuildContext context)=>MaterialApp(theme:ThemeData(fontFamily:'Geist',extensions:[BeuiColors.light()]),home:Builder(builder:(context){
 probe={'mode':mode,'calls':calls,'ownerOrder':items,'disabled':disabled,'reduce':MediaQuery.disableAnimationsOf(context)}.jsify();
 return CallbackShortcuts(bindings:{
 SingleActivator(LogicalKeyboardKey.keyR):()=>setState(()=>items=['A','B','C']),
 SingleActivator(LogicalKeyboardKey.keyM):()=>setState(()=>items=['B','A','D']),
 SingleActivator(LogicalKeyboardKey.keyI):()=>setState(()=>items=['B','A','C']),
 SingleActivator(LogicalKeyboardKey.keyD):()=>setState(()=>disabled=true),
 },child:Scaffold(body:Center(child:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Sortable Undo fixture'),BeuiSortableList<String>(defaultItems:const ['A','B','C'],items:mode=='uncontrolled'?null:items,disabled:disabled,getItemId:(x)=>x,getItemLabel:(x)=>x,onItemsChange:(v)=>setState((){calls.add(v.toList());if(mode!='reject')items=v;}),renderItem:(x,i)=>Text(x)),TextButton(onPressed:(){},child:const Text('After list'))])))));
 }));
}
