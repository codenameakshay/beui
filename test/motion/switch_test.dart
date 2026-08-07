import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _thumb = ValueKey<String>('beui_switch_thumb');

/// Wraps a [BeuiSwitch] in a themed app. [reduce] forces reduced motion.
Widget _app({
  required bool value,
  ValueChanged<bool>? onChanged,
  bool enabled = true,
  bool reduce = false,
  String? label,
}) {
  Widget child = Center(
    child: BeuiSwitch(
      key: const ValueKey('sw'),
      value: value,
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
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: child),
  );
}

double _thumbX(WidgetTester tester) => tester.getTopLeft(find.byKey(_thumb)).dx;

void main() {
  group('BeuiSwitch interaction', () {
    testWidgets('tap toggles via onChanged', (tester) async {
      bool? changed;
      await tester.pumpWidget(
        _app(value: false, onChanged: (v) => changed = v),
      );
      await tester.tap(find.byType(BeuiSwitch));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('disabled does not toggle', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _app(value: false, enabled: false, onChanged: (_) => called = true),
      );
      await tester.tap(find.byType(BeuiSwitch), warnIfMissed: false);
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

  group('BeuiSwitch semantics', () {
    testWidgets('exposes toggled + enabled state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(value: true, label: 'Wifi'));
      expect(
        tester.getSemantics(find.byType(BeuiSwitch)),
        isSemantics(
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled reports not enabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(value: false, enabled: false));
      expect(
        tester.getSemantics(find.byType(BeuiSwitch)),
        isSemantics(isToggled: false, isEnabled: false),
      );
      handle.dispose();
    });
  });

  group('BeuiSwitch motion fidelity', () {
    testWidgets('thumb glides over time under normal motion', (tester) async {
      await tester.pumpWidget(_app(value: false));
      await tester.pumpAndSettle();
      final offX = _thumbX(tester);

      await tester.pumpWidget(_app(value: true));
      await tester.pump(const Duration(milliseconds: 30));
      final midX = _thumbX(tester);
      await tester.pumpAndSettle();
      final onX = _thumbX(tester);

      // Mid-flight the thumb is past the start but not yet settled — i.e. it is
      // actually animating, not snapping.
      expect(midX, greaterThan(offX));
      expect(midX, lessThan(onX));
      expect(onX, greaterThan(offX));
    });

    testWidgets('thumb snaps with no glide under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(_app(value: false, reduce: true));
      await tester.pumpAndSettle();
      final offX = _thumbX(tester);

      await tester.pumpWidget(_app(value: true, reduce: true));
      await tester.pump(const Duration(milliseconds: 1));
      final immediateX = _thumbX(tester);
      await tester.pumpAndSettle();
      final settledX = _thumbX(tester);

      // Travel happened (so the thumb did move to the on position)...
      expect(settledX, greaterThan(offX));
      // ...but it was instant: one frame in, it is already at the settled spot.
      expect(immediateX, closeTo(settledX, 0.5));
    });
  });

  testWidgets('rest-state golden (on / off / disabled)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BeuiSwitch(value: true, onChanged: _noop, label: 'On'),
                SizedBox(height: 12),
                BeuiSwitch(value: false, onChanged: _noop, label: 'Off'),
                SizedBox(height: 12),
                BeuiSwitch(
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
      matchesGoldenFile('goldens/beui_switch.png'),
    );
  });
}

void _noop(bool _) {}
