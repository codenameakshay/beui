import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/sortable_list.dart';
import 'package:beui/src/theme/beui_colors.dart';

Widget app({List<String>? items, ValueChanged<List<String>>? change,
 bool second = false, bool firstEnabled = true, bool secondEnabled = true,
 bool showFirst = true, int generation = 0, FocusNode? outside,
 VoidCallback? firstPress, VoidCallback? secondPress,
 Key? rootKey, bool reparent = false, bool visible = true}) {
 final list = BeuiSortableList<String>(key: rootKey,
  defaultItems: const ['A','B','C'], items: items,
  getItemId: (s)=>s, getItemLabel: (s)=>s, onItemsChange: change,
  children: (values)=>Column(mainAxisSize: MainAxisSize.min,children:[
   BeuiSortableListGroup(children:[for(final id in values)
    BeuiSortableListItem(id:id,child:Row(children:[
     if(showFirst) BeuiSortableListHandle(key: ValueKey('$id-first-$generation'),enabled:firstEnabled, onPressed:firstPress, child: Text('$id-first')),
     if(second) BeuiSortableListHandle(key: ValueKey('$id-second'),enabled:secondEnabled, onPressed:secondPress, child: Text('$id-second')),
     Text(id),
    ])),]), const BeuiSortableListUndo(),]));
 return MaterialApp(theme: ThemeData(extensions:[BeuiColors.light()]), home:Scaffold(body:Column(children:[
  if(visible) SizedBox(width:400,child:reparent?Padding(padding:const EdgeInsets.all(1),child:list):list),
  TextButton(focusNode:outside,onPressed:(){},child:const Text('Outside')),
 ])));
}
Finder button(String label)=>find.ancestor(of:find.text(label), matching:find.byType(IconButton));
FocusNode node(WidgetTester t,String label)=>Focus.of(t.element(find.text(label)));
Future<void> focus(WidgetTester t,String label) async {node(t,label).requestFocus();await t.pump();}
VoidCallback undo(WidgetTester t)=>t.widget<TextButton>(find.ancestor(of:find.text('Undo reorder'),matching:find.byType(TextButton))).onPressed!;
Future<void> key(WidgetTester t,LogicalKeyboardKey k) async {await t.sendKeyEvent(k);await t.pumpAndSettle();}
void main(){
 testWidgets('Enter activates the requested first handle callback',(t)async{
  final calls=<String>[];
  await t.pumpWidget(app(second:true,firstPress:()=>calls.add('first'),secondPress:()=>calls.add('second')));
  await focus(t,'A-first');await key(t,LogicalKeyboardKey.enter);
  expect(calls,['first']);
 });

 testWidgets('two enabled handles preserve independent focus ownership',(t)async{
  await t.pumpWidget(app(second:true));
  await focus(t,'A-first');
  expect(node(t,'A-first').context, isNotNull);
  final primary=FocusManager.instance.primaryFocus;
  expect(primary?.context?.findAncestorWidgetOfExactType<IconButton>()?.icon,
    isA<Text>().having((w)=>w.data,'focused handle','A-first'));
 });
 testWidgets('disabled second handle does not disable first handle',(t)async{
  var calls=0;
  await t.pumpWidget(app(second:true,secondEnabled:false,change:(_)=>calls++));
  await focus(t,'A-first');
  await key(t,LogicalKeyboardKey.arrowDown);
  expect(calls,1);
 });
 testWidgets('removing second handle leaves first usable',(t)async{
  var calls=0;
  await t.pumpWidget(app(second:true,change:(_)=>calls++));
  await focus(t,'A-second');
  await t.pumpWidget(app(second:false,change:(_)=>calls++));
  await t.pumpAndSettle();
  await focus(t,'A-first');
  await key(t,LogicalKeyboardKey.arrowDown);
  expect(calls,1);
 });
 testWidgets('key remount keeps replacement handle usable',(t)async{
  var calls=0;
  await t.pumpWidget(app(change:(_)=>calls++));
  await focus(t,'A-first');
  await t.pumpWidget(app(generation:1,change:(_)=>calls++));
  await t.pumpAndSettle();
  await focus(t,'A-first');
  await key(t,LogicalKeyboardKey.arrowDown);
  expect(calls,1);
 });
 for(final accept in [true,false]) {
 testWidgets('controlled Undo accept=$accept respects already focused external owner',(t)async{
  final external=FocusNode();addTearDown(external.dispose);
  var values=['A','B','C'];var calls=0;
  await t.pumpWidget(StatefulBuilder(builder:(context,set)=>app(items:values,outside:external,change:(next){
   calls++; if(calls==1 || accept) set(()=>values=next);
   if(calls==2) external.requestFocus();
  })));
  await focus(t,'A-first');await key(t,LogicalKeyboardKey.end);
  external.requestFocus();await t.pump();expect(external.hasPrimaryFocus,isTrue);
  undo(t)();await t.pumpAndSettle();
  expect(external.hasPrimaryFocus,isTrue);
  expect(values,accept?['A','B','C']:['B','C','A']);
  expect(calls,2);
 });
 }
 testWidgets('membership removes focused handle and reintroduces fresh usable handle',(t)async{
  var values=['A','B','C'];late StateSetter set;var calls=0;
  await t.pumpWidget(StatefulBuilder(builder:(c,s){set=s;return app(items:values,change:(_)=>calls++);}));
  await focus(t,'A-first');
  set(()=>values=['B','C']);await t.pumpAndSettle();
  set(()=>values=['A','B','C']);await t.pumpAndSettle();
  await focus(t,'A-first');await key(t,LogicalKeyboardKey.arrowDown);expect(calls,1);
 });
 testWidgets('focused root reparent and disposal preserve external focus',(t)async{
  final root=GlobalKey();final external=FocusNode();addTearDown(external.dispose);
  await t.pumpWidget(app(rootKey:root,outside:external));await focus(t,'A-first');
  final original=FocusManager.instance.primaryFocus;
  await t.pumpWidget(app(rootKey:root,reparent:true,outside:external));await t.pumpAndSettle();
  expect(FocusManager.instance.primaryFocus,same(original));
  external.requestFocus();await t.pump();
  await t.pumpWidget(app(rootKey:root,visible:false,outside:external));await t.pumpAndSettle();
  expect(external.hasPrimaryFocus,isTrue);
 });
 testWidgets('disabled sole handle is not chosen by Undo',(t)async{
  var enabled=true;late StateSetter set;
  await t.pumpWidget(StatefulBuilder(builder:(c,s){set=s;return app(firstEnabled:enabled);}));
  await focus(t,'A-first');await key(t,LogicalKeyboardKey.end);
  set(()=>enabled=false);await t.pumpAndSettle();
  undo(t)();await t.pumpAndSettle();expect(node(t,'A-first').hasFocus,isFalse);
 });
}
