import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';
FocusNode cell(WidgetTester t,int r,int m) {
 final f=find.byKey(ValueKey('beui-returns-cell-$r-$m'));
 final ink=find.ancestor(of:f, matching:find.byType(InkWell));
 return t.widget<InkWell>(ink.evaluate().isEmpty?f:ink).focusNode!;
}
void main(){
 testWidgets('reverse without grid replacement', (t) async {
 Future<void> show(List<int> years) async {await t.pumpWidget(beuiTestApp(BeuiReturnsCalendar(years:years),reduce:true));await t.pumpAndSettle();}
 await show([2024,2025]);cell(t,1,2).requestFocus();await t.pumpAndSettle();await show([2024,2030]);
 await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);await t.pumpAndSettle();expect(cell(t,0,12).hasPrimaryFocus,isTrue);
 });
 testWidgets('whole calendar teardown', (t) async {
 await t.pumpWidget(beuiTestApp(const BeuiReturnsCalendar(years:[2024,2025]),reduce:true));
 cell(t,1,2).requestFocus();await t.pumpAndSettle();
 await t.pumpWidget(beuiTestApp(const Text('gone'),reduce:true));await t.pumpAndSettle();
 expect(t.takeException(),isNull);
 });
 testWidgets('grid replacement does not delete live registration', (t) async {
 Future<void> show(int key,List<int> years) async {
 await t.pumpWidget(beuiTestApp(BeuiReturnsCalendar(years:years,child:BeuiReturnsCalendarGrid(key:ValueKey(key))),reduce:true));await t.pumpAndSettle();
 }
 await show(0,[2024,2025]);
 await show(1,[2024,2025]);
 cell(t,1,2).requestFocus();await t.pumpAndSettle();
 await show(1,[2024,2030]);
 await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);await t.pumpAndSettle();
 expect(cell(t,0,12).hasPrimaryFocus,isTrue);
 });
 testWidgets('global keyed calendar reparent preserves focus', (t) async {
 final key=GlobalKey();
 Future<void> show(bool move) async {
 final cal=BeuiReturnsCalendar(key:key,years:const[2024,2025]);
 await t.pumpWidget(beuiTestApp(Column(children:[if(!move) cal,if(move) Padding(padding:EdgeInsets.zero,child:cal)]),reduce:true));await t.pumpAndSettle();
 }
 await show(false);final old=cell(t,1,2);old.requestFocus();await t.pumpAndSettle();
 await show(true);expect(cell(t,1,2),same(old));expect(old.hasPrimaryFocus,isTrue);
 });
 testWidgets('duplicate years render', (t) async {
 await t.pumpWidget(beuiTestApp(const BeuiReturnsCalendar(years:[2024,2024]),reduce:true));
 expect(t.takeException(),isNull);
 });
 testWidgets('outside focus is not stolen on row replacement', (t) async {
 final outside=FocusNode();addTearDown(outside.dispose);
 Future<void> show(List<int> years) async {
 await t.pumpWidget(beuiTestApp(Column(children:[TextButton(focusNode:outside,onPressed:(){},child:const Text('outside')),BeuiReturnsCalendar(years:years)]),reduce:true));await t.pumpAndSettle();
 }
 await show([2024,2025]);cell(t,1,2).requestFocus();await t.pumpAndSettle();await show([2024,2030]);
 outside.requestFocus();await t.pumpAndSettle();await show([2024,2040]);expect(outside.hasPrimaryFocus,isTrue);
 await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.pumpAndSettle();expect(cell(t,0,0).hasPrimaryFocus,isTrue);
 });
}
