import 'package:beui/src/motion/_hit_target.dart'
    show BeuiMinHitTarget, beuiMinHitTarget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required VoidCallback onTap,
  double minSize = beuiMinHitTarget,
  bool enabled = true,
}) {
  // The default test surface is 800x600; a 20x20 target centred in it has
  // ample margin on every side for the widest slop used below (60px), so no
  // extra Stack/Align scaffolding is needed to keep off-centre taps on
  // screen.
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: BeuiMinHitTarget(
          key: const ValueKey('hit'),
          minSize: minSize,
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('BeuiMinHitTarget layout', () {
    testWidgets('painted size is unchanged', (tester) async {
      await tester.pumpWidget(_app(onTap: () {}));
      expect(tester.getSize(find.byType(BeuiMinHitTarget)), const Size(20, 20));
    });
  });

  group('BeuiMinHitTarget hit slop', () {
    testWidgets('a tap at the centre lands', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_app(onTap: () => tapped = true));
      final center = tester.getCenter(find.byKey(const ValueKey('hit')));
      await tester.tapAt(center);
      expect(tapped, isTrue);
    });

    testWidgets('a tap outside the 20px paint but inside the 44px slop lands', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(_app(onTap: () => tapped = true));
      final center = tester.getCenter(find.byKey(const ValueKey('hit')));
      // 15px out: outside the 20px child (half-width 10) but inside the
      // 44px slop (half-width 22).
      await tester.tapAt(center + const Offset(15, 0));
      expect(tapped, isTrue);
    });

    testWidgets('a tap outside the 44px slop does not land', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_app(onTap: () => tapped = true));
      final center = tester.getCenter(find.byKey(const ValueKey('hit')));
      // 30px out: outside the 44px slop (half-width 22).
      await tester.tapAt(center + const Offset(30, 0));
      expect(tapped, isFalse);
    });
  });

  group('BeuiMinHitTarget enabled: false', () {
    testWidgets('is a pass-through — no slop beyond the paint', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_app(onTap: () => tapped = true, enabled: false));
      final center = tester.getCenter(find.byKey(const ValueKey('hit')));

      await tester.tapAt(center + const Offset(15, 0));
      expect(tapped, isFalse);

      // The child itself is still reachable — only the slop is disabled.
      await tester.tapAt(center);
      expect(tapped, isTrue);
    });
  });

  group('BeuiMinHitTarget custom minSize', () {
    testWidgets('honours a wider slop', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_app(onTap: () => tapped = true, minSize: 60));
      final center = tester.getCenter(find.byKey(const ValueKey('hit')));
      // 25px out: outside the default 44px slop (half-width 22) but inside
      // the custom 60px slop (half-width 30).
      await tester.tapAt(center + const Offset(25, 0));
      expect(tapped, isTrue);
    });
  });
}
