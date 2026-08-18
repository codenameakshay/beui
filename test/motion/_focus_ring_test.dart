import 'package:beui/beui.dart';
import 'package:beui/src/motion/_focus_ring.dart' show BeuiFocusRing;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required bool focused,
  required Widget child,
  Color? color,
  BeuiColors? colors,
  bool reduce = false,
}) {
  Widget ring = Center(
    child: BeuiFocusRing(
      key: const ValueKey('ring'),
      focused: focused,
      color: color,
      child: child,
    ),
  );
  if (reduce) {
    // See the same note in _disclosure_test.dart: capture the subtree in a
    // fresh local, or the closure reads the reassigned `ring` and nests
    // itself until the stack blows.
    final inner = ring;
    ring = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: [colors ?? BeuiColors.light()],
    ),
    home: Scaffold(body: ring),
  );
}

/// The ring itself: a [DecoratedBox] whose [BoxDecoration] carries a border.
/// `_frame`'s reduce-to-`SizedBox.shrink()` when fully transparent means this
/// only exists while the ring has non-zero opacity.
Finder _ringBorder() => find.descendant(
  of: find.byKey(const ValueKey('ring')),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border != null,
  ),
);

Color _borderColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_ringBorder());
  final border = (box.decoration as BoxDecoration).border! as Border;
  return border.top.color;
}

void main() {
  group('BeuiFocusRing layout', () {
    testWidgets('is identical focused and unfocused (SizedBox child)', (
      tester,
    ) async {
      const childKey = ValueKey('child');
      const child = SizedBox(key: childKey, width: 120, height: 40);

      await tester.pumpWidget(_app(focused: false, child: child));
      await tester.pumpAndSettle();
      final sizeBefore = tester.getSize(find.byKey(childKey));
      final topLeftBefore = tester.getTopLeft(find.byKey(childKey));

      await tester.pumpWidget(_app(focused: true, child: child));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(childKey)), sizeBefore);
      expect(tester.getTopLeft(find.byKey(childKey)), topLeftBefore);
    });

    testWidgets('is identical focused and unfocused (Text child)', (
      tester,
    ) async {
      const child = Text('Focusable label', key: ValueKey('text-child'));

      await tester.pumpWidget(_app(focused: false, child: child));
      await tester.pumpAndSettle();
      final sizeBefore = tester.getSize(
        find.byKey(const ValueKey('text-child')),
      );

      await tester.pumpWidget(_app(focused: true, child: child));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('text-child'))),
        sizeBefore,
      );
    });
  });

  group('BeuiFocusRing paint', () {
    testWidgets('ring is painted when focused, absent when not', (
      tester,
    ) async {
      const child = SizedBox(width: 120, height: 40);

      await tester.pumpWidget(_app(focused: false, child: child));
      await tester.pumpAndSettle();
      expect(_ringBorder(), findsNothing);

      await tester.pumpWidget(_app(focused: true, child: child));
      await tester.pumpAndSettle();
      expect(_ringBorder(), findsOneWidget);
    });

    testWidgets('reads BeuiColors.focusRing, not .ring', (tester) async {
      final colors = BeuiColors.light();
      await tester.pumpWidget(
        _app(
          focused: true,
          colors: colors,
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      await tester.pumpAndSettle();
      expect(_borderColor(tester), colors.focusRing);
      expect(_borderColor(tester), isNot(colors.ring));
    });

    testWidgets('an explicit color overrides the token', (tester) async {
      const custom = Color(0xFF123456);
      await tester.pumpWidget(
        _app(
          focused: true,
          color: custom,
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      await tester.pumpAndSettle();
      expect(_borderColor(tester), custom);
    });
  });

  group('BeuiFocusRing reduced motion', () {
    testWidgets('the fade still runs — opacity is not a movement channel', (
      tester,
    ) async {
      const child = SizedBox(width: 120, height: 40);

      await tester.pumpWidget(_app(focused: false, reduce: true, child: child));
      await tester.pump();

      await tester.pumpWidget(_app(focused: true, reduce: true, child: child));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 70),
      ); // partway through the 150ms fade

      final opacityFinder = find.descendant(
        of: find.byKey(const ValueKey('ring')),
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsOneWidget);
      final opacity = tester.widget<Opacity>(opacityFinder).opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));

      await tester.pump(const Duration(milliseconds: 90)); // settle
      expect(_ringBorder(), findsOneWidget);
    });
  });

  group('BeuiFocusRing hit testing', () {
    testWidgets('the ring does not intercept pointers', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          home: Scaffold(
            body: Center(
              child: BeuiFocusRing(
                focused: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapped = true,
                  child: const SizedBox(
                    key: ValueKey('btn'),
                    width: 120,
                    height: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Target the GestureDetector, not the bare SizedBox: with
      // `HitTestBehavior.opaque` the detector is what claims the hit, so the
      // SizedBox never appears in the hit-test result and `warnIfMissed`
      // would flag it even though the tap lands correctly.
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });
  });
}
