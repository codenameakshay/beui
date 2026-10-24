import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';
FocusNode cell(WidgetTester t,int r,int m) { final f=find.byKey(ValueKey('beui-returns-cell-$r-$m')); final ink=find.ancestor(of:f, matching:find.byType(InkWell)); return t.widget<InkWell>(ink.evaluate().isEmpty?f:ink).focusNode!; }
void main(){
 testWidgets('global grid moves between owners then replacement', (t) async {
 final grid=GlobalKey();
 Future<void> show(bool moved,List<int> years) async {
 await t.pumpWidget(beuiTestApp(Column(children:[
 BeuiReturnsCalendar(key:const ValueKey('a'),years:const[2024,2025], child:moved?const SizedBox():BeuiReturnsCalendarGrid(key:grid)),
 BeuiReturnsCalendar(key:const ValueKey('b'),years:years, child:moved?BeuiReturnsCalendarGrid(key:grid):const SizedBox()),
 ]),reduce:true));await t.pumpAndSettle();
 }
 await show(false,[2024,2025]);final march=cell(t,1,2);march.requestFocus();await t.pumpAndSettle();
 await show(true,[2024,2025]);expect(cell(t,1,2),same(march));expect(march.hasPrimaryFocus,true);
 await show(true,[2024,2030]);
 await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);await t.pumpAndSettle();
 expect(cell(t,0,12).hasPrimaryFocus,true);
 });
 testWidgets('old owner cannot unfocus moved grid', (t) async {
 final grid=GlobalKey();
 Future<void> show(bool moved,List<int> oldYears) async {
 await t.pumpWidget(beuiTestApp(Column(children:[
 BeuiReturnsCalendar(key:const ValueKey('a'),years:oldYears, child:moved?const SizedBox():BeuiReturnsCalendarGrid(key:grid)),
 BeuiReturnsCalendar(key:const ValueKey('b'),years:const[2024,2025], child:moved?BeuiReturnsCalendarGrid(key:grid):const SizedBox()),
 ]),reduce:true));await t.pumpAndSettle();
 }
 await show(false,[2024,2025]);final march=cell(t,1,2);march.requestFocus();await t.pumpAndSettle();
 await show(true,[2024,2025]);expect(march.hasPrimaryFocus,true);
 await show(true,[2024,2030]);expect(cell(t,1,2),same(march));
 expect(march.hasPrimaryFocus,true);
 });
 testWidgets('repeated replacement retains pending position', (t) async {
 Future<void> show(List<int> years) async {await t.pumpWidget(beuiTestApp(BeuiReturnsCalendar(years:years),reduce:true));await t.pumpAndSettle();}
 await show([2024,2025]);cell(t,1,2).requestFocus();await t.pumpAndSettle();await show([2024,2030]);await show([2024,2040]);await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.pumpAndSettle();expect(cell(t,1,0).hasPrimaryFocus,true);
 });
 testWidgets('outside cell focus cancels pending position', (t) async {
 Future<void> show(List<int> years) async {await t.pumpWidget(beuiTestApp(BeuiReturnsCalendar(years:years),reduce:true));await t.pumpAndSettle();}
 await show([2024,2025]);cell(t,1,2).requestFocus();await t.pumpAndSettle();await show([2024,2030]);cell(t,0,2).requestFocus();await t.pumpAndSettle();await show([2024,2040]);await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.pumpAndSettle();expect(cell(t,0,3).hasPrimaryFocus,true);
 });
}
