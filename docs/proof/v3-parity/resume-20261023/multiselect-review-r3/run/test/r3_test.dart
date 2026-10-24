import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/multi_select.dart';
const items=[BeuiMultiSelectOption(value:'a',label:'Alpha'),BeuiMultiSelectOption(value:'b',label:'Beta')];
void main(){
for(final override in [false,true]) {
testWidgets('external chip acquisition precedes owner override=$override',(t) async {
final external=FocusNode(debugLabel:'external');addTearDown(external.dispose);
final events=<String>[];
await t.pumpWidget(MaterialApp(home:Scaffold(body:Column(children:[SizedBox(width:340,child:BeuiMultiSelect(items:items,defaultValue:const ['a'],onOpenChanged:(v)=>events.add('open:$v'),onChanged:(v){expect(FocusManager.instance.primaryFocus?.debugLabel,'beui_multi_select');events.add('selection:$v');if(override)external.requestFocus();})),const SizedBox(height:250),TextField(focusNode:external)]))));
external.requestFocus();await t.pumpAndSettle();events.clear();
await t.tap(find.bySemanticsLabel('Remove Alpha'));await t.idle();await t.pumpAndSettle();
expect(events,override?['open:true','selection:[]','open:false']:['open:true','selection:[]']);expect(external.hasFocus,override);
});}
testWidgets('query and closed open rejection without rebuild',(t)async{
final queries=<String>[];final opens=<bool>[];
await t.pumpWidget(MaterialApp(home:Scaffold(body:BeuiMultiSelect(items:items,query:'kept',open:false,onQueryChanged:queries.add,onOpenChanged:opens.add))));
await t.tap(find.byType(TextField));await t.pumpAndSettle();opens.clear();
t.testTextInput.enterText('attempt');await t.pumpAndSettle();
expect(queries,['attempt']);expect(opens,[true]);expect(t.widget<TextField>(find.byType(TextField)).controller!.text,'kept');expect(find.byType(BeuiMultiSelectList),findsNothing);
});
testWidgets('explicit popup focus is internal boundary',(t)async{
final opens=<bool>[];final queries=<String>[];
await t.pumpWidget(MaterialApp(home:Scaffold(body:SizedBox(width:340,child:BeuiMultiSelect(items:items,onOpenChanged:opens.add,onQueryChanged:queries.add)))));
await t.tap(find.byType(TextField));await t.pumpAndSettle();opens.clear();queries.clear();
final node=FocusManager.instance.rootScope.descendants.firstWhere((n)=>n.context?.findAncestorWidgetOfExactType<BeuiMultiSelectItem>()!=null && n.canRequestFocus);
node.requestFocus();await t.pumpAndSettle();expect(node.hasFocus,isTrue);expect(opens,isEmpty);expect(queries,isEmpty);expect(find.byType(BeuiMultiSelectList),findsOneWidget);
});
}
