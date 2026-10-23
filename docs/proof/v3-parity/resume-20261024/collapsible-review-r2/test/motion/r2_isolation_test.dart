import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/collapsible.dart';
import '../support.dart';
void main() {
 for(final reduce in [false,true]) {
  for(final scenario in ['stale history','pending inside','outside then inside','controlled to uncontrolled','uncontrolled to controlled','cross-scope reparent pending','cross-scope reparent open','plain focus reparent']) {
   testWidgets('$scenario reduce=$reduce',(tester) async {
    final inside=FocusNode(debugLabel:'inside'), other=FocusNode(debugLabel:'other'), outside=FocusNode(debugLabel:'outside');
    addTearDown(() {inside.dispose();other.dispose();outside.dispose();});
    bool? open=scenario=='uncontrolled to controlled'?null:true;
    var moved=false, pending=false;
    final key=GlobalKey();late StateSetter update;
    await tester.pumpWidget(beuiTestApp(StatefulBuilder(builder:(context,setState){
      update=setState;
      if(pending){pending=false;if(scenario=='pending inside')other.requestFocus();else if(scenario=='outside then inside'){outside.requestFocus();other.requestFocus();}else outside.requestFocus();}
      final panel=scenario=='plain focus reparent'?FocusScope(key:key,child:ExcludeFocus(excluding:open==false,child:Focus(focusNode:inside,child:const Text('Plain')))):BeuiCollapsible(key:key,open:open,defaultOpen:scenario=='uncontrolled to controlled',child:Column(mainAxisSize:MainAxisSize.min,children:[const BeuiCollapsibleTrigger(child:Text('Toggle')),BeuiCollapsibleContent(child:Column(mainAxisSize:MainAxisSize.min,children:[Focus(focusNode:inside,child:const Text('Inside')),Focus(focusNode:other,child:const Text('Other'))]))]));
      return Column(mainAxisSize:MainAxisSize.min,children:[FocusScope(child:moved?const SizedBox():panel),FocusScope(child:moved?panel:const SizedBox()),Focus(focusNode:outside,child:const Text('Outside'))]);
    }),reduce:reduce,width:600));
    await tester.pumpAndSettle();
    inside.requestFocus();await tester.pump();
    if(scenario=='stale history'){outside.requestFocus();await tester.pump();}
    update((){open=scenario=='controlled to uncontrolled'?null:scenario=='cross-scope reparent open';pending=['pending inside','outside then inside','cross-scope reparent pending','cross-scope reparent open','plain focus reparent'].contains(scenario);moved=scenario.startsWith('cross-scope')||scenario=='plain focus reparent';});
    await tester.pumpAndSettle();
    if(moved) debugPrint('R2 $scenario focus=${FocusManager.instance.primaryFocus}');
    expect(FocusManager.instance.primaryFocus?.debugLabel,['stale history','cross-scope reparent pending','cross-scope reparent open','plain focus reparent'].contains(scenario)?'outside':'collapsible trigger');
    expect(tester.takeException(),isNull);
   });
  }
 }
}
