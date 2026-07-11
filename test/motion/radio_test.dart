import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _dot = ValueKey<String>('beui_radio_dot');

Widget _app({
  String? value,
  String? defaultValue,
  ValueChanged<String>? onChanged,
  bool reduce = false,
}) {
  Widget child = Center(
    child: BeuiRadioGroup<String>(
      key: const ValueKey('rg'),
      value: value,
      defaultValue: defaultValue,
      onChanged: onChanged,
      items: const [
        BeuiRadioItem(value: 'a', label: 'A'),
        BeuiRadioItem(value: 'b', label: 'B'),
        BeuiRadioItem(value: 'c', label: 'C'),
        BeuiRadioItem(value: 'd', label: 'D', enabled: false),
      ],
    ),
  );
  if (reduce) {
    final inner = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: child),
  );
}

double _dotY(WidgetTester tester) => tester.getTopLeft(find.byKey(_dot)).dy;

SemanticsNode _itemSemantics(WidgetTester tester, String value) =>
    tester.getSemantics(
      find.byWidgetPredicate(
        (w) => w is BeuiRadioItem<String> && w.value == value,
      ),
    );

void main() {
  group('BeuiRadioGroup interaction', () {
    testWidgets('tap selects via onChanged (controlled)', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(value: 'a', onChanged: (v) => changed = v));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(changed, 'b');
    });

    testWidgets('uncontrolled selection moves the dot', (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'a'));
      await tester.pumpAndSettle();
      final yA = _dotY(tester);

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      final yC = _dotY(tester);

      expect(yC, greaterThan(yA)); // C is below A, dot followed
      expect(_itemSemantics(tester, 'c'), isSemantics(isChecked: true));
    });

    testWidgets('disabled item does not select', (tester) async {
      String? changed;
      await tester.pumpWidget(
        _app(defaultValue: 'a', onChanged: (v) => changed = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('D'), warnIfMissed: false);
      await tester.pump();
      expect(changed, isNull);
    });

    testWidgets('Space activates the focused item', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(value: 'a', onChanged: (v) => changed = v));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changed, isNotNull);
    });
  });

  group('BeuiRadioGroup semantics', () {
    testWidgets('selected item is checked + mutually exclusive', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(value: 'b'));
      await tester.pumpAndSettle();
      expect(
        _itemSemantics(tester, 'b'),
        isSemantics(
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          isEnabled: true,
        ),
      );
      expect(_itemSemantics(tester, 'a'), isSemantics(isChecked: false));
      handle.dispose();
    });

    testWidgets('disabled item reports not enabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(value: 'a'));
      await tester.pumpAndSettle();
      expect(_itemSemantics(tester, 'd'), isSemantics(isEnabled: false));
      handle.dispose();
    });
  });

  group('BeuiRadioGroup motion fidelity', () {
    testWidgets('dot glides between items under normal motion', (tester) async {
      await tester.pumpWidget(_app(value: 'a'));
      await tester.pumpAndSettle();
      final yA = _dotY(tester);

      await tester.pumpWidget(_app(value: 'c'));
      await tester.pump(); // let the post-frame measure retarget the dot
      await tester.pump(const Duration(milliseconds: 40));
      final yMid = _dotY(tester);
      await tester.pumpAndSettle();
      final yC = _dotY(tester);

      expect(yMid, greaterThan(yA));
      expect(yMid, lessThan(yC));
      expect(yC, greaterThan(yA));
    });

    testWidgets('dot snaps to selection under reduced motion', (tester) async {
      await tester.pumpWidget(_app(value: 'a', reduce: true));
      await tester.pumpAndSettle();
      final yA = _dotY(tester);

      await tester.pumpWidget(_app(value: 'c', reduce: true));
      await tester.pump(); // measure retargets
      await tester.pump(const Duration(milliseconds: 1));
      final yImmediate = _dotY(tester);
      await tester.pumpAndSettle();
      final yC = _dotY(tester);

      expect(yC, greaterThan(yA));
      expect(yImmediate, closeTo(yC, 0.5));
    });
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_app(value: 'b'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiRadioGroup<String>),
      matchesGoldenFile('goldens/beui_radio.png'),
    );
  });
}
