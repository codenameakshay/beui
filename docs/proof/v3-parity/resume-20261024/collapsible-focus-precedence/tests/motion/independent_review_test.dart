import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/collapsible.dart';
import '../support.dart';
void main() {
 for(final reduce in [false,true]) {
  for(final scenario in ['accepted','rejected','pending-build','pending-before','dispose','reparent','disabled','multiple']) {
   testWidgets('$scenario reduce=$reduce',(tester) async {
    final inside=FocusNode(debugLabel:'inside');
    final outside=FocusNode(debugLabel:'outside');
    final second=FocusNode(debugLabel:'second');
    addTearDown(() {inside.dispose();outside.dispose();second.dispose();});
    var open=true,alive=true,moved=false,requestInBuild=false;
    final key=GlobalKey();
    final calls=<bool>[];
    late StateSetter update;
    Widget panel() => BeuiCollapsible(key:key,open:open,disabled:scenario=='disabled',onOpenChange:(v){calls.add(v);if(scenario!='rejected') update(()=>open=v);},child:Column(mainAxisSize:MainAxisSize.min,children:[
     const BeuiCollapsibleTrigger(child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.add),Text('Custom toggle')])),
     BeuiCollapsibleContent(child:Padding(padding:const EdgeInsets.all(3),child:Focus(focusNode:inside,child:const Text('Custom content')))),
    ]));
    await tester.pumpWidget(beuiTestApp(StatefulBuilder(builder:(context,setState){
     update=setState;
     if(requestInBuild){requestInBuild=false;outside.requestFocus();}
     final c=panel();
     return Column(mainAxisSize:MainAxisSize.min,children:[
      if(alive) Row(children:[Expanded(child:moved?const SizedBox():c),Expanded(child:moved?c:const SizedBox())]),
      Focus(focusNode:outside,child:const Text('Outside')),
      BeuiCollapsible(open:true,child:Column(mainAxisSize:MainAxisSize.min,children:[const BeuiCollapsibleTrigger(child:Text('Second')),BeuiCollapsibleContent(child:Focus(focusNode:second,child:const Text('Second content')))])),
     ]);
    }),reduce:reduce,width:600));
    await tester.pumpAndSettle();
    (scenario=='multiple'?second:inside).requestFocus();await tester.pump();
    if(['accepted','rejected','disabled'].contains(scenario)) {
     await tester.tap(find.text('Custom toggle'));
    } else {
     update(() {open=false;if(scenario=='dispose')alive=false;if(scenario=='reparent')moved=true;if(scenario=='pending-build')requestInBuild=true;});
     if(scenario=='pending-before'||scenario=='dispose')outside.requestFocus();
    }
    await tester.pumpAndSettle();
    if(scenario=='pending-build'||scenario=='pending-before'||scenario=='dispose') expect(outside.hasFocus,isTrue,reason:'owner outside request must win; actual=${FocusManager.instance.primaryFocus?.debugLabel}');
    else if(scenario=='multiple')expect(second.hasFocus,isTrue);
    else if(scenario=='rejected'||scenario=='disabled')expect(inside.hasFocus,isTrue);
    else expect(FocusManager.instance.primaryFocus?.debugLabel,'collapsible trigger');
    expect(calls,scenario=='accepted'||scenario=='rejected'?[false]:isEmpty);
    expect(tester.takeException(),isNull);
   });
  }
 }
}
