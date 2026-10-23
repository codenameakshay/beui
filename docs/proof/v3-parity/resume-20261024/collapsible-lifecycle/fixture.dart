import 'dart:async';
import 'dart:js_interop';
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
@JS('globalThis.__fixture') external set probe(JSAny? value);
void main(){runApp(const Fixture());}
class Fixture extends StatefulWidget{const Fixture({super.key});@override State<Fixture> createState()=>_FixtureState();}
class _FixtureState extends State<Fixture>{
 bool open=true,disabled=false,alive=true,narrow=false; final calls=<bool>[]; final height=ValueNotifier<double>(40); final panel=GlobalKey();final inner=GlobalKey(); late final Widget content; late Timer timer;
 final reject=Uri.base.queryParameters['owner']=='reject';final uncontrolled=Uri.base.queryParameters['owner']=='uncontrolled';
 @override void initState(){super.initState();content=BeuiCollapsibleContent(key:panel,child:ValueListenableBuilder<double>(valueListenable:height,builder:(context,h,_)=>LayoutBuilder(builder:(context,c)=>Column(mainAxisSize:MainAxisSize.min,children:[const TextField(decoration:InputDecoration(labelText:'Inside')),SizedBox(key:inner,height:h+(c.maxWidth<200?80:0),child:const ColoredBox(color:Colors.teal,child:Center(child:Text('Content extent'))))]))));timer=Timer.periodic(const Duration(milliseconds:100),(_)=>publish());}
 void publish(){double? size(GlobalKey k)=>(k.currentContext?.findRenderObject() as RenderBox?)?.size.height;probe={'open':open,'calls':calls,'disabled':disabled,'alive':alive,'height':size(panel),'inner':size(inner),'focus':FocusManager.instance.primaryFocus?.debugLabel,'reduce':WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations}.jsify();}
 @override void dispose(){timer.cancel();height.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>MaterialApp(theme:ThemeData(extensions:[BeuiColors.light()]),home:CallbackShortcuts(bindings:{const SingleActivator(LogicalKeyboardKey.keyC,alt:true):()=>setState(()=>open=false),const SingleActivator(LogicalKeyboardKey.keyO,alt:true):()=>setState(()=>open=true),const SingleActivator(LogicalKeyboardKey.keyD,alt:true):()=>setState(()=>disabled=!disabled),const SingleActivator(LogicalKeyboardKey.keyX,alt:true):()=>setState(()=>alive=false)},child:Scaffold(body:Align(alignment:Alignment.topCenter,child:Padding(padding:const EdgeInsets.only(top:60),child:Column(children:[const Text('Supplemental public composition: Collapsible lifecycle'),SizedBox(width:narrow?180:320,child:alive?BeuiCollapsible(open:uncontrolled?null:open,defaultOpen:true,disabled:disabled,onOpenChange:(v)=>setState((){calls.add(v);if(!reject)open=v;}),child:Column(mainAxisSize:MainAxisSize.min,children:[const BeuiCollapsibleTrigger(child:Text('Toggle')),content])):const SizedBox()),const SizedBox(width:320,child:TextField(decoration:InputDecoration(labelText:'Outside'))),Wrap(children:[TextButton(onPressed:()=>height.value=140,child:const Text('Grow')),TextButton(onPressed:()=>height.value=20,child:const Text('Shrink')),TextButton(onPressed:()=>setState(()=>narrow=!narrow),child:const Text('Width'))])]))))));
}
