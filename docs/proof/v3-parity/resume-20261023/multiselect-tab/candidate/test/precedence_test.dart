import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/multi_select.dart';
const items=[BeuiMultiSelectOption(value:'a',label:'Alpha'),BeuiMultiSelectOption(value:'b',label:'Beta')];
void main(){
 for(final mode in ['same previous owner','new owner','outside blank','owner unfocus']) {
 testWidgets(mode,(t) async {
 final external=FocusNode(debugLabel:'external');addTearDown(external.dispose);
 await t.pumpWidget(MaterialApp(home:Scaffold(body:Column(children:[SizedBox(width:340,child:BeuiMultiSelect(items:items,defaultValue:const ['a'],onChanged:(_){if(mode.contains('owner') && mode!='owner unfocus') external.requestFocus();if(mode=='owner unfocus') FocusManager.instance.primaryFocus?.unfocus();})),const SizedBox(height:250),TextField(key:const Key('external'),focusNode:external),const SizedBox(key:Key('blank'),height:100,width:300)]))));
 if(mode=='same previous owner'){external.requestFocus();await t.pump();expect(external.hasFocus,isTrue);}
 if(mode=='owner unfocus'){await t.tap(find.byType(TextField).first);await t.pumpAndSettle();}
 await t.tap(find.bySemanticsLabel('Remove Alpha'));
 if(mode=='outside blank')await t.tapAt(t.getCenter(find.byKey(const Key('blank'))));
 await t.idle();
 debugPrint('BEFORE $mode primary=${FocusManager.instance.primaryFocus?.debugLabel} external=${external.hasFocus}');
 await t.pumpAndSettle();
 debugPrint('AFTER $mode primary=${FocusManager.instance.primaryFocus?.debugLabel} external=${external.hasFocus}');
 expect(t.widget<TextField>(find.byType(TextField).first).focusNode!.hasFocus,isFalse);
 if(mode.contains('owner') && mode!='owner unfocus')expect(external.hasFocus,isTrue);
 });
 }
 testWidgets('remove button accessible name and action',(t)async{
 final semantics=t.ensureSemantics();
 await t.pumpWidget(const MaterialApp(home:Scaffold(body:BeuiMultiSelect(items:items,defaultValue:['a']))));
 final node=t.getSemantics(find.bySemanticsLabel('Remove Alpha'));
 expect(node.getSemanticsData().label,'Remove Alpha');
 expect(node.getSemanticsData().hasFlag(SemanticsFlag.isButton),isTrue);
 expect(node.getSemanticsData().hasAction(SemanticsAction.tap),isTrue);
 expect(find.byType(Tooltip),findsNothing);
 semantics.dispose();
 });
}
