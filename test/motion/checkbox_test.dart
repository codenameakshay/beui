import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a [BeuiCheckbox] in a themed app. [reduce] forces reduced motion.
Widget _app({
  required bool value,
  ValueChanged<bool>? onChanged,
  bool enabled = true,
  bool indeterminate = false,
  bool reduce = false,
  String? label,
}) {
  Widget child = Center(
    child: BeuiCheckbox(
      key: const ValueKey('cb'),
      value: value,
      indeterminate: indeterminate,
      enabled: enabled,
      label: label,
      onChanged: onChanged ?? (_) {},
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

Finder _mark() => find.descendant(
  of: find.byType(BeuiCheckbox),
  matching: find.byType(CustomPaint),
);

void main() {
  group('BeuiCheckbox interaction', () {
    testWidgets('tap toggles via onChanged', (tester) async {
      bool? changed;
      await tester.pumpWidget(
        _app(value: false, onChanged: (v) => changed = v),
      );
      await tester.tap(find.byType(BeuiCheckbox));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('disabled does not toggle', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _app(value: false, enabled: false, onChanged: (_) => called = true),
      );
      await tester.tap(find.byType(BeuiCheckbox), warnIfMissed: false);
      await tester.pump();
      expect(called, isFalse);
    });

    testWidgets('Space activates when focused', (tester) async {
      bool? changed;
      await tester.pumpWidget(
        _app(value: false, onChanged: (v) => changed = v),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changed, isTrue);
    });
  });

  group('BeuiCheckbox mark', () {
    testWidgets('present when checked, absent when unchecked', (tester) async {
      await tester.pumpWidget(_app(value: false));
      await tester.pumpAndSettle();
      expect(_mark(), findsNothing);

      await tester.pumpWidget(_app(value: true));
      await tester.pumpAndSettle();
      expect(_mark(), findsOneWidget);
    });

    testWidgets('present in indeterminate state', (tester) async {
      await tester.pumpWidget(_app(value: false, indeterminate: true));
      await tester.pumpAndSettle();
      expect(_mark(), findsOneWidget);
    });
  });

  group('BeuiCheckbox semantics', () {
    testWidgets('checked reports checked state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(value: true, label: 'Terms'));
      expect(
        tester.getSemantics(find.byType(BeuiCheckbox)),
        isSemantics(hasCheckedState: true, isChecked: true, isEnabled: true),
      );
      handle.dispose();
    });

    testWidgets('indeterminate reports mixed state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(value: true, indeterminate: true));
      expect(
        tester.getSemantics(find.byType(BeuiCheckbox)),
        isSemantics(isCheckStateMixed: true),
      );
      handle.dispose();
    });

    testWidgets('disabled reports not enabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(value: false, enabled: false));
      expect(
        tester.getSemantics(find.byType(BeuiCheckbox)),
        isSemantics(isChecked: false, isEnabled: false),
      );
      handle.dispose();
    });
  });

  group('BeuiCheckbox motion fidelity', () {
    testWidgets('mark scales in under normal motion', (tester) async {
      await tester.pumpWidget(_app(value: true));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BeuiCheckbox),
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reduced motion drops scale, keeps opacity', (tester) async {
      await tester.pumpWidget(_app(value: true, reduce: true));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BeuiCheckbox),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(BeuiCheckbox),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
    });
  });

  testWidgets(
    'rest-state golden (checked / unchecked / indeterminate / disabled)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          home: const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BeuiCheckbox(value: true, onChanged: _noop, label: 'Checked'),
                  SizedBox(height: 12),
                  BeuiCheckbox(
                    value: false,
                    onChanged: _noop,
                    label: 'Unchecked',
                  ),
                  SizedBox(height: 12),
                  BeuiCheckbox(
                    value: true,
                    indeterminate: true,
                    onChanged: _noop,
                    label: 'Indeterminate',
                  ),
                  SizedBox(height: 12),
                  BeuiCheckbox(
                    value: true,
                    enabled: false,
                    onChanged: _noop,
                    label: 'Disabled',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Column),
        matchesGoldenFile('goldens/beui_checkbox.png'),
      );
    },
  );
}

void _noop(bool _) {}
