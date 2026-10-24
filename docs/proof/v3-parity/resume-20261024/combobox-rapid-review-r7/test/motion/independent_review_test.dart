import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/combobox.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';

Widget _testApp(Widget child, {bool reduce = false}) => MaterialApp(
  theme: BeuiTextTheme.trackingNormal(
    ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[BeuiColors.light()],
    ),
  ),
  home: Scaffold(
    body: Center(
      child: reduce
          ? Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child,
              ),
            )
          : child,
    ),
  ),
);

Widget _combobox({
  ValueChanged<String>? onValueChange,
  ValueChanged<bool>? onOpenChange,
  ValueChanged<String>? onQueryChange,
  String? value,
  String? defaultValue,
  bool? open,
  bool defaultOpen = false,
  String? query,
  String defaultQuery = '',
  bool reduce = false,
}) => _testApp(
  SizedBox(
    width: 260,
    child: BeuiCombobox(
      value: value,
      defaultValue: defaultValue,
      onValueChange: onValueChange,
      open: open,
      defaultOpen: defaultOpen,
      onOpenChange: onOpenChange,
      query: query,
      defaultQuery: defaultQuery,
      onQueryChange: onQueryChange,
      trigger: const BeuiComboboxTrigger(
        child: BeuiComboboxInput(label: 'Search fruits'),
      ),
      content: const BeuiComboboxContent(
        child: BeuiComboboxList(
          ariaLabel: 'Fruits',
          children: <Widget>[
            BeuiComboboxEmpty(child: Text('Nothing found')),
            BeuiComboboxGroup(
              label: 'Fresh',
              children: <Widget>[
                BeuiComboboxItem(
                  value: 'apple',
                  textValue: 'Apple',
                  keywords: <String>['red fruit'],
                  child: Text('Apple'),
                ),
                BeuiComboboxItem(
                  value: 'banana',
                  textValue: 'Banana',
                  child: Text('Banana'),
                ),
                BeuiComboboxItem(
                  value: 'cherry',
                  textValue: 'Cherry',
                  disabled: true,
                  child: Text('Cherry'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
  reduce: reduce,
);


void main() {
  for (final sameNode in [false, true]) {
    testWidgets('pending owner focus precedence sameNode=$sameNode', (tester) async {
      final outside = FocusNode();
      addTearDown(outside.dispose);
      await tester.pumpWidget(_testApp(Column(children: [
        Focus(focusNode: outside, child: const Text('Outside')),
        Expanded(child: _combobox()),
      ])));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      outside.requestFocus();
      if (sameNode) field.focusNode!.requestFocus();
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'ban', selection: TextSelection.collapsed(offset: 3)));
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, sameNode);
      expect(outside.hasFocus, !sameNode);
      expect(field.controller!.text, 'ban');
    });
  }
  testWidgets('programmatic controlled updates do not emit editing requests', (tester) async {
    final events = <String>[];
    Widget build(bool open, String query) => _combobox(open: open, query: query,
      onOpenChange: (v) => events.add('open:$v'), onQueryChange: (v) => events.add('query:$v'));
    await tester.pumpWidget(build(true, 'ban'));
    await tester.pumpAndSettle();
    events.clear();
    await tester.pumpWidget(build(true, 'app'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'app');
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Banana'), findsNothing);
    await tester.pumpWidget(build(false, 'app'));
    await tester.pumpAndSettle();
    expect(events, isEmpty);
  });
  testWidgets('burst edits exact callback order and re-registration selection', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(_combobox(onOpenChange: (v) => events.add('open:$v'),
      onQueryChange: (v) => events.add('query:$v'), onValueChange: (v) => events.add('value:$v')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    events.clear();
    for (final text in ['b', 'ba', 'ban']) {
      tester.testTextInput.updateEditingValue(TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
    }
    expect(events, ['open:true','query:b','open:true','query:ba','open:true','query:ban']);
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(events.sublist(6), ['value:banana','open:false','query:']);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Banana');
  });
  for (final reparent in [false,true]) {
    testWidgets('pending open focus survives lifecycle reparent=$reparent', (tester) async {
      final key = GlobalKey();
      Widget combo() => BeuiCombobox(key: key, trigger: const BeuiComboboxTrigger(child: BeuiComboboxInput()), content: const BeuiComboboxContent(child: BeuiComboboxList(children: [BeuiComboboxItem(value:'b',child:Text('B'))])));
      await tester.pumpWidget(_testApp(Row(children:[Expanded(child:combo()), const SizedBox()])));
      await tester.pumpAndSettle();
      tester.widget<TextField>(find.byType(TextField)).onTap!();
      await tester.pumpWidget(reparent ? _testApp(Row(children:[const SizedBox(),Expanded(child:combo())])) : _testApp(const Text('Removed')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (reparent) expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
    });
  }
}
