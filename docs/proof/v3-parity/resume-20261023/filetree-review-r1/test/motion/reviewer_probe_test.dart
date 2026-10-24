import 'dart:ui' show Tristate, SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/file_tree.dart';

void main() {
  testWidgets('default selected disabled node survives enable and controlled selection updates', (tester) async {
    final handle = tester.ensureSemantics();
    final calls = <String>[];
    Widget fixture({bool disabled = true, String? value}) => MaterialApp(home: Scaffold(body: BeuiFileTree(
      defaultValue: 'b', value: value, onChanged: calls.add,
      children: [const BeuiFileTreeFile(value:'a',name:'A'), BeuiFileTreeFile(value:'b',name:'B',disabled:disabled)],
    )));
    List<SemanticsData> data() {
      final out = <SemanticsData>[];
      void visit(SemanticsNode n) {out.add(n.getSemanticsData()); n.visitChildren((c){visit(c);return true;});}
      visit(tester.getSemantics(find.byType(BeuiFileTree)));return out;
    }
    SemanticsData button(String label) => data().singleWhere((d)=>d.label==label && d.flagsCollection.isButton);
    await tester.pumpWidget(fixture());await tester.pumpAndSettle();
    expect(button('B').flagsCollection.isSelected,Tristate.isTrue);
    expect(button('B').flagsCollection.isEnabled,Tristate.isFalse);
    expect(button('B').hasAction(SemanticsAction.tap),false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);await tester.pumpAndSettle();
    for(final key in [LogicalKeyboardKey.enter,LogicalKeyboardKey.space]) {await tester.sendKeyEvent(key);await tester.pumpAndSettle();}
    expect(calls,isEmpty);expect(button('B').flagsCollection.isSelected,Tristate.isTrue);
    await tester.pumpWidget(fixture(disabled:false));await tester.pumpAndSettle();
    expect(button('B').flagsCollection.isSelected,Tristate.isTrue);expect(button('B').hasAction(SemanticsAction.tap),true);
    await tester.pumpWidget(fixture(value:'a'));await tester.pumpAndSettle();
    expect(button('A').flagsCollection.isSelected,Tristate.isTrue);expect(button('B').flagsCollection.isSelected,Tristate.isFalse);
    await tester.pumpWidget(fixture(value:'b'));await tester.pumpAndSettle();
    expect(button('B').flagsCollection.isSelected,Tristate.isTrue);expect(button('B').flagsCollection.isEnabled,Tristate.isFalse);expect(calls,isEmpty);
    handle.dispose();
  });
  testWidgets('independent content semantics actions preserve row selection and callback isolation', (tester) async {
    final handle = tester.ensureSemantics(); final calls=<String>[];final selected=<String>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:BeuiFileTree(defaultValue:'other',onChanged:selected.add,children:[
      const BeuiFileTreeFile(value:'other',name:'Other'),
      BeuiFileTreeFile(value:'file',name:'File',icon:Row(children:[for(final label in ['Inspect','Pin']) Expanded(child:Semantics(button:true,label:label,child:GestureDetector(behavior:HitTestBehavior.opaque,onTap:()=>calls.add(label),child:const SizedBox(height:16))))])),
    ]))));await tester.pumpAndSettle();
    for(final label in ['Inspect','Pin']) {
      final node=tester.getSemantics(find.bySemanticsLabel(label));
      tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id,SemanticsAction.tap);await tester.pump();
      await tester.tap(find.bySemanticsLabel(label));await tester.pump();
    }
    expect(calls,['Inspect','Inspect','Pin','Pin']);expect(selected,isEmpty);
    handle.dispose();
  });
}
