import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/multi_select.dart';
const items=[BeuiMultiSelectOption(value:'a',label:'Alpha'),BeuiMultiSelectOption(value:'b',label:'Beta')];
Widget app(Widget child)=>MaterialApp(home:Scaffold(body:Column(children:[SizedBox(width:340,child:child)])));
void main(){
 testWidgets('Escape proposes closing exactly once',(t)async{
 final opens=<bool>[]; final queries=<String>[];
 await t.pumpWidget(app(BeuiMultiSelect(items:items,onOpenChanged:opens.add,onQueryChanged:queries.add)));
 await t.tap(find.byType(TextField));await t.pumpAndSettle(); opens.clear();queries.clear();
 await t.sendKeyEvent(LogicalKeyboardKey.escape);await t.pumpAndSettle();
 expect(opens,[false]);expect(queries,['']);
 });
 testWidgets('external pointer focus between chip tap and frame is preserved',(t) async {
 final external=FocusNode(); addTearDown(external.dispose);
 await t.pumpWidget(MaterialApp(home:Scaffold(body:Column(children:[const SizedBox(width:340,child:BeuiMultiSelect(items:items,defaultValue:['a'])),const SizedBox(height:250),TextField(key:const Key('external'),focusNode:external)]))));
 await t.tap(find.bySemanticsLabel('Remove Alpha'));
 await t.tap(find.byKey(const Key('external')));
 await t.idle();
 expect(external.hasFocus,isTrue,reason:'external pointer established focus before next frame');
 await t.pumpAndSettle();
 expect(t.widget<TextField>(find.byType(TextField).first).focusNode!.hasFocus,isFalse,reason:'stale chip callback must not steal focus');
 final field=t.widget<TextField>(find.byKey(const Key('external')));
 expect(field.focusNode!.hasFocus,isTrue);
 });
 for(final replace in [false,true]){
 testWidgets('owner removes or replaces synchronously replace=$replace',(t)async{
 var alive=true; var epoch=0; final opens=<bool>[];
 await t.pumpWidget(StatefulBuilder(builder:(c,set)=>app(alive?BeuiMultiSelect(key:ValueKey(epoch),items:items,defaultValue:const ['a'],onChanged:(_)=>set((){if(replace){epoch++;}else{alive=false;}}),onOpenChanged:opens.add):const Text('removed'))));
 await t.tap(find.bySemanticsLabel('Remove Alpha'));await t.pumpAndSettle();
 expect(t.takeException(),isNull);
 expect(find.byType(BeuiMultiSelectList),findsNothing);
 if(replace) expect(find.bySemanticsLabel('Remove Alpha'),findsOneWidget);
 });}
 testWidgets('second instance tap dismisses first and retains second focus',(t)async{
 await t.pumpWidget(MaterialApp(home:Scaffold(body:Column(children:[const SizedBox(width:340,child:BeuiMultiSelect(items:items,defaultValue:['a'])),const SizedBox(height:250),const SizedBox(width:340,child:BeuiMultiSelect(items:items))]))));
 await t.tap(find.byType(TextField).first);await t.pumpAndSettle();
 await t.tap(find.byType(TextField).last);await t.pumpAndSettle();
 expect(find.byType(BeuiMultiSelectList),findsOneWidget);
 expect(t.widget<TextField>(find.byType(TextField).last).focusNode!.hasFocus,isTrue);
 });
}
