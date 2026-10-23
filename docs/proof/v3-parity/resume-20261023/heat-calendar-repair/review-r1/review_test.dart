import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';
Finder cell(int w,int d)=>find.byKey(ValueKey('beui-heat-cell-$w-$d'));
Finder legend(int n)=>find.bySemanticsLabel('Filter activity level $n');
bool selected(WidgetTester t,int n)=>t.widget<Semantics>(legend(n)).properties.selected!;
Widget chart({int end=23,int weeks=4, BeuiHeatCalendarSelection? selection})=>beuiTestApp(Column(children:[TextButton(onPressed:(){},child:const Text('before')),BeuiHeatCalendar(weeks:weeks,endDate:DateTime.utc(2026,10,end),selection:selection,values:List.generate(4,(_)=>[0,.2,.4,.6,.8,1,0])),TextButton(onPressed:(){},child:const Text('after'))]));
void main(){
 testWidgets('continuation prototype waits for Tab and respects outside focus',(t)async{
  await t.pumpWidget(chart());await t.tap(cell(3,4));await t.sendKeyEvent(LogicalKeyboardKey.escape);await t.pumpAndSettle();await t.pumpWidget(chart(end:19));await t.pumpAndSettle();
  expect(FocusManager.instance.primaryFocus,isA<FocusScopeNode>());expect(find.text('commits'),findsNothing);expect(selected(t,0),false);
  await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.pumpAndSettle();expect(selected(t,0),true);
  await t.pumpWidget(chart());await t.pumpAndSettle();await t.tap(cell(3,4));await t.sendKeyEvent(LogicalKeyboardKey.escape);await t.pumpAndSettle();await t.pumpWidget(chart(end:19));await t.pumpAndSettle();
  Focus.of(t.element(find.text('after'))).requestFocus();await t.pumpAndSettle();await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.pumpAndSettle();expect(selected(t,0),false);expect(FocusManager.instance.primaryFocus!.context, isNotNull);
 });

 testWidgets('keyboard legend activation blur and teardown',(t)async{
  await t.pumpWidget(chart());await t.tap(cell(3,4));await t.sendKeyEvent(LogicalKeyboardKey.escape);await t.pumpAndSettle();await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.pumpAndSettle();expect(selected(t,0),true);
  await t.sendKeyEvent(LogicalKeyboardKey.enter);await t.pumpAndSettle();expect(selected(t,0),false);await t.sendKeyEvent(LogicalKeyboardKey.space);await t.pumpAndSettle();expect(selected(t,0),true);
  Focus.of(t.element(find.text('after'))).requestFocus();await t.pumpAndSettle();expect(selected(t,0),false);await t.pumpWidget(const SizedBox());await t.pumpAndSettle();expect(t.takeException(),isNull);
 });
 testWidgets('removal preserves external focus',(t)async{
  await t.pumpWidget(chart());await t.tap(cell(3,4));await t.sendKeyEvent(LogicalKeyboardKey.escape);await t.pumpAndSettle();Focus.of(t.element(find.text('after'))).requestFocus();await t.pumpAndSettle();final previous=FocusManager.instance.primaryFocus;await t.pumpWidget(chart(end:19));await t.pumpAndSettle();expect(FocusManager.instance.primaryFocus,same(previous));await t.pumpWidget(const SizedBox());await t.pumpAndSettle();expect(t.takeException(),isNull);
 });
 testWidgets('invalid locked endpoint does not retain selection',(t)async{
  await t.pumpWidget(chart());await t.tap(cell(0,0));await t.pumpAndSettle();await t.tap(cell(3,4));await t.pumpAndSettle();await t.pumpWidget(chart(end:19));await t.pumpAndSettle();
  final s=find.descendant(of:cell(0,0),matching:find.byType(Semantics));
  // A new click should anchor rather than clear a stale locked range.
  await t.tap(cell(1,0));await t.pumpAndSettle();
  final semantics=find.ancestor(of:cell(1,0),matching:find.byWidgetPredicate((w)=>w is Semantics && w.properties.label?.contains('commits on')==true));
  expect(t.widget<Semantics>(semantics).properties.selected,true);
 });
}
