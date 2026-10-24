import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/combobox.dart';

Widget app({required bool open, required String query, bool reduce=false, String item='banana', String label='Banana', List<String> keywords=const [], bool disabled=false, ValueChanged<String>? selected}) => MaterialApp(home: MediaQuery(data: MediaQueryData(disableAnimations: reduce), child: Scaffold(body: Center(child: SizedBox(width: 260, child: BeuiCombobox(open: open, query: query, onValueChange: selected, trigger: const BeuiComboboxTrigger(child: BeuiComboboxInput()), content: BeuiComboboxContent(child: BeuiComboboxList(children: [const BeuiComboboxEmpty(child: Text('Empty')), BeuiComboboxGroup(label: 'Fruit', children: [BeuiComboboxItem(key: const ValueKey('changing'), value:item, textValue: label, keywords:keywords, disabled:disabled, child:Text(label)), const BeuiComboboxItem(value:'apple', textValue:'Apple', child:Text('Apple'))])]))))))));
void main() {
 for (final reduce in [false,true]) {
  testWidgets('independent repeated controlled interruptions and final teardown reduce=$reduce', (t) async {
   await t.pumpWidget(app(open:true,query:'ban',reduce:reduce)); await t.pumpAndSettle();
   for(final gap in [0,1,25,79,80,150,299,301]) {
    await t.pumpWidget(app(open:false,query:'apl',reduce:reduce));
    await t.pump(Duration(milliseconds:gap));
    if (gap==1) { expect(find.text('Banana'),findsOneWidget); expect(find.text('Apple'),findsNothing); }
    await t.pumpWidget(app(open:true,query:'apl',reduce:reduce)); await t.pumpAndSettle();
    expect(find.text('Apple'),findsOneWidget); expect(find.text('Banana'),findsNothing);
    final panel=find.byType(BeuiComboboxList); expect(t.getSize(panel).height,greaterThan(0));
    final fades=t.widgetList<FadeTransition>(find.ancestor(of:panel,matching:find.byType(FadeTransition)));
    expect(fades,isNotEmpty); for(final f in fades) {expect(f.opacity.value,1);}
    await t.pumpWidget(app(open:true,query:'ban',reduce:reduce)); await t.pumpAndSettle();
   }
   await t.pumpWidget(app(open:false,query:'',reduce:reduce)); await t.pump(const Duration(milliseconds:1));
   await t.pumpWidget(const MaterialApp(home:Text('Removed'))); await t.pumpAndSettle();
   await t.sendKeyEvent(LogicalKeyboardKey.escape); await t.pump();
   expect(t.takeException(),isNull); expect(find.text('Removed'),findsOneWidget);
  });
  testWidgets('independent item identity label keyword disabled updates through exit reduce=$reduce', (t) async {
   final selected=<String>[];
   await t.pumpWidget(app(open:true,query:'ban',reduce:reduce,selected:selected.add)); await t.pumpAndSettle();
   await t.pumpWidget(app(open:false,query:'',reduce:reduce,selected:selected.add)); await t.pump(const Duration(milliseconds:10));
   await t.pumpWidget(app(open:false,query:'',reduce:reduce,item:'pear',label:'Pear',keywords:['ban'],selected:selected.add)); await t.pump(const Duration(milliseconds:1));
   expect(find.text('Pear'),findsOneWidget); expect(find.text('Banana'),findsNothing);
   await t.pumpWidget(app(open:true,query:'ban',reduce:reduce,item:'pear',label:'Pear',keywords:['ban'],disabled:true,selected:selected.add)); await t.pumpAndSettle();
   await t.tap(find.text('Pear')); await t.pump(); expect(selected,isEmpty);
   await t.pumpWidget(app(open:true,query:'ban',reduce:reduce,item:'pear',label:'Pear',keywords:['ban'],selected:selected.add)); await t.pumpAndSettle();
   await t.tap(find.text('Pear')); await t.pumpAndSettle(); expect(selected,['pear']);
   await t.pumpWidget(app(open:true,query:'apl',reduce:reduce,item:'pear',label:'Pear',keywords:['ban'],selected:selected.add)); await t.pumpAndSettle();
   expect(find.text('Apple'),findsOneWidget); expect(find.text('Pear'),findsNothing); expect(find.text('Empty'),findsNothing);
  });
 }
 testWidgets('independent removing open owner releases focus and deferred callbacks', (t) async {
  await t.pumpWidget(app(open:false,query:'ban')); await t.pumpAndSettle();
  await t.tap(find.byType(TextField)); await t.pump();
  await t.pumpWidget(app(open:true,query:'ban')); await t.pumpAndSettle();
  final old=t.widget<TextField>(find.byType(TextField)).focusNode!; expect(old.hasFocus,isTrue);
  await t.pumpWidget(const MaterialApp(home:Scaffold(body:TextField(autofocus:true)))); await t.pumpAndSettle();
  await t.enterText(find.byType(TextField),'new owner'); await t.sendKeyEvent(LogicalKeyboardKey.escape); await t.pumpAndSettle();
  expect(find.text('new owner'),findsOneWidget); expect(FocusManager.instance.primaryFocus, isNot(same(old))); expect(t.takeException(),isNull);
 });
}
