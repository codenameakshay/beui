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
    testWidgets(
      'selection brackets expand while dragging and settle on release',
      (tester) async {
        await tester.pumpWidget(_app(defaultValue: 'two'));
        await tester.pumpAndSettle();
        final brackets = find.ancestor(
          of: find.text('['),
          matching: find.byType(Row),
        );
        final rest = tester.getSize(brackets).width;
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Dawn')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getSize(brackets).width, greaterThan(rest + 6));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.getSize(brackets).width, closeTo(rest, .01));
      },
    );

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

    testWidgets('bracket width springs between labels of different widths', (
      tester,
    ) async {
      await tester.pumpWidget(_app(defaultValue: 'two'));
      final bracketRow = find.ancestor(
        of: find.text('['),
        matching: find.byType(Row),
      );
      final initialWidth = tester.getSize(bracketRow).width;

      await tester.tap(find.text('Daybreak'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final transitioningWidth = tester.getSize(bracketRow).width;
      await tester.pumpAndSettle();
      final settledWidth = tester.getSize(bracketRow).width;

      expect(settledWidth, greaterThan(initialWidth));
      expect(transitioningWidth, greaterThan(initialWidth));
      expect(transitioningWidth, lessThan(settledWidth));
    });

    testWidgets('reduced motion snaps bracket geometry for controlled labels', (
      tester,
    ) async {
      Widget app(String value) => beuiTestApp(
        BeuiArcPicker(
          options: _options,
          value: value,
          side: BeuiArcPickerSide.left,
          visibleCount: 5,
          itemHeight: 40,
        ),
        reduce: true,
        width: 320,
        fontFamily: 'Ahem',
      );
      await tester.pumpWidget(app('two'));
      final bracket = find.ancestor(
        of: find.text('['),
        matching: find.byType(Row),
      );
      final stack = find.descendant(
        of: find.byType(BeuiArcPicker),
        matching: find.byType(Stack),
      );
      double bracketLeft() =>
          tester.getTopLeft(bracket).dx - tester.getTopLeft(stack).dx;
      expect(tester.getSize(bracket).width, closeTo(152, 0.01));
      expect(bracketLeft(), closeTo(23.2, 0.001));

      await tester.pumpWidget(app('three'));
      expect(tester.getSize(bracket).width, closeTo(248, 0.01));
      expect(bracketLeft(), closeTo(-72.8, 0.001));
      expect(find.text('Daybreak'), findsOneWidget);
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

      await tester.pumpWidget(app('three'));
      expect(tester.getSize(bracket).width, closeTo(248, 0.01));
      expect(bracketLeft(), closeTo(-72.8, 0.001));
      await tester.pumpWidget(app('two'));
      expect(tester.getSize(bracket).width, closeTo(152, 0.01));
      expect(bracketLeft(), closeTo(23.2, 0.001));
    });

    testWidgets('empty options render the empty state under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiArcPicker(options: [], value: 'missing'),
          reduce: true,
          width: 320,
        ),
      );
      expect(find.text('No options'), findsOneWidget);
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
