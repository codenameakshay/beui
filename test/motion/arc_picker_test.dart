import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _options = <BeuiArcPickerOption>[
  BeuiArcPickerOption(value: 'one', label: 'First light'),
  BeuiArcPickerOption(value: 'two', label: 'Dawn'),
  BeuiArcPickerOption(value: 'three', label: 'Daybreak'),
  BeuiArcPickerOption(value: 'four', label: 'Sunrise'),
  BeuiArcPickerOption(value: 'five', label: 'Morning'),
];

Widget _app({
  String? value,
  String? defaultValue,
  ValueChanged<String>? onChanged,
  BeuiArcPickerSide side = BeuiArcPickerSide.right,
  bool disabled = false,
  bool reduce = false,
  int visibleCount = 5,
  double itemHeight = 40,
}) => beuiTestApp(
  BeuiArcPicker(
    options: _options,
    value: value,
    defaultValue: defaultValue,
    onChanged: onChanged,
    side: side,
    disabled: disabled,
    visibleCount: visibleCount,
    itemHeight: itemHeight,
    semanticLabel: 'Time of day',
  ),
  reduce: reduce,
  width: 320,
);

void main() {
  group('BeuiArcPicker selection', () {
    testWidgets('uncontrolled selection starts at default and changes by tap', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _app(defaultValue: 'two', onChanged: (value) => changed = value),
      );
      expect(find.text('Dawn'), findsOneWidget);
      await tester.tap(find.text('Daybreak'));
      await tester.pumpAndSettle();
      expect(changed, 'three');
      expect(
        find.ancestor(
          of: find.text('Daybreak'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.checked == true,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('controlled selection reports without taking ownership', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _app(value: 'one', onChanged: (value) => changed = value),
      );
      await tester.tap(find.text('Dawn'));
      await tester.pump();
      expect(changed, 'two');
      expect(
        find.ancestor(
          of: find.text('First light'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.checked == true,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dragging crosses choices and publishes the new selection', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _app(defaultValue: 'one', onChanged: (value) => changed = value),
      );
      await tester.drag(find.byType(BeuiArcPicker), const Offset(0, -85));
      await tester.pumpAndSettle();
      expect(changed, isNot('one'));
    });

    testWidgets('arrow keys skip disabled choices and Home/End jump', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiArcPicker(
            options: const [
              BeuiArcPickerOption(value: 'a', label: 'Alpha'),
              BeuiArcPickerOption(value: 'b', label: 'Beta', disabled: true),
              BeuiArcPickerOption(value: 'c', label: 'Charlie'),
            ],
            defaultValue: 'a',
            onChanged: (value) => changed = value,
          ),
          width: 320,
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(changed, 'c');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(changed, 'a');
    });

    testWidgets('disabled options and picker do not change selection', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(defaultValue: 'one', disabled: true, onChanged: (_) => calls++),
      );
      await tester.tap(find.text('Dawn'), warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(calls, 0);
    });

    testWidgets('reduced motion keeps keyboard selection usable', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _app(
          defaultValue: 'one',
          reduce: true,
          onChanged: (value) => changed = value,
        ),
      );
      await tester.tap(find.text('First light'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changed, 'two');
    });

    testWidgets('top and bottom preserve the group semantic label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(defaultValue: 'one', side: BeuiArcPickerSide.top),
      );
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(BeuiArcPicker)),
        isSemantics(label: 'Time of day', isEnabled: true),
      );
      expect(_options.length, 5);
      handle.dispose();
    });
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: BeuiArcPicker(
                options: _options,
                defaultValue: 'three',
                side: BeuiArcPickerSide.right,
                visibleCount: 5,
                itemHeight: 40,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiArcPicker),
      matchesGoldenFile('goldens/beui_arc_picker.png'),
    );
  });
}
