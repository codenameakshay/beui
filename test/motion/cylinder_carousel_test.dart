import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

List<Widget> _balls([int n = 7]) => [
  for (var i = 0; i < n; i++)
    DecoratedBox(
      key: ValueKey('ball$i'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF3366CC + i * 0x001100),
      ),
    ),
];

/// Wraps a [BeuiCylinderCarousel] at a fixed size in a themed app.
Widget _app({
  BeuiCylinderCurve curve = BeuiCylinderCurve.concave,
  ValueChanged<int>? onIndexChange,
  int defaultIndex = 0,
  int? index,
  bool snap = true,
  bool autoRotate = false,
  bool reduce = false,
}) {
  final carousel = SizedBox(
    height: 200,
    child: BeuiCylinderCarousel(
      curve: curve,
      itemSize: 120,
      height: 200,
      snap: snap,
      autoRotate: autoRotate,
      defaultIndex: defaultIndex,
      index: index,
      onIndexChange: onIndexChange,
      children: _balls(),
    ),
  );
  return beuiTestApp(carousel, width: 400, reduce: reduce);
}

void main() {
  group('BeuiCylinderCarousel interaction', () {
    testWidgets('drag rolls the wall and reports an index change', (
      tester,
    ) async {
      int? reported;
      await tester.pumpWidget(_app(onIndexChange: (i) => reported = i));
      await tester.pump();

      final center = tester.getCenter(find.byType(BeuiCylinderCarousel));
      final g = await tester.startGesture(center);
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(-40, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();

      expect(reported, isNotNull);
      expect(reported, isNot(0));
    });

    testWidgets(
      'a hard flick projects up to ~6 items (clamps the momentum product, '
      'not the raw velocity)',
      (tester) async {
        int? reported;
        await tester.pumpWidget(_app(onIndexChange: (i) => reported = i));
        await tester.pump();

        final center = tester.getCenter(find.byType(BeuiCylinderCarousel));
        // A short, very fast drag: 8px in 8ms → ~1 px/ms → ~22.5 items/s of
        // release velocity, well past the point where FLICK_MOMENTUM (0.45)
        // saturates the ±MAX_FLICK_ITEMS (6) cap. The source clamps the
        // *product* (velocity × momentum), so the projected travel maxes out
        // at 6 items. The fixed bug clamped the *raw velocity* to ±6 first,
        // which capped travel at 6 × 0.45 = 2.7 items → a settled index of ~3
        // instead of ~6.
        final g = await tester.startGesture(center); // pointer down at t=0
        await g.moveBy(
          const Offset(-8, 0),
          timeStamp: const Duration(milliseconds: 8),
        );
        await g.up();
        await tester.pumpAndSettle();

        // Started at index 0; a saturated flick rolls ~6 items forward. Under
        // the pre-fix clamp this would only reach ~3.
        expect(reported, isNotNull);
        expect(reported, greaterThanOrEqualTo(5));
      },
    );

    testWidgets('arrow keys roll by one item', (tester) async {
      int? reported;
      await tester.pumpWidget(_app(onIndexChange: (i) => reported = i));
      await tester.pump();

      // Focus the carousel via a pointer down/up, then roll right.
      await tester.tap(find.byType(BeuiCylinderCarousel));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(reported, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(reported, 0);
    });

    testWidgets('wheel scroll rolls and settles', (tester) async {
      int? reported;
      await tester.pumpWidget(_app(onIndexChange: (i) => reported = i));
      await tester.pump();

      final center = tester.getCenter(find.byType(BeuiCylinderCarousel));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(center));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
      await tester.pumpAndSettle();
      expect(reported, isNotNull);
      expect(reported, isNot(0));
    });
  });

  group('BeuiCylinderCarousel controlled', () {
    testWidgets('index prop glides to the requested item', (tester) async {
      int? reported;
      await tester.pumpWidget(
        _app(index: 0, onIndexChange: (i) => reported = i),
      );
      await tester.pump();
      await tester.pumpWidget(
        _app(index: 3, onIndexChange: (i) => reported = i),
      );
      await tester.pumpAndSettle();
      expect(reported, 3);
    });
  });

  group('BeuiCylinderCarousel reduced motion', () {
    testWidgets('release snaps instantly (no glide spring)', (tester) async {
      int? reported;
      await tester.pumpWidget(
        _app(reduce: true, onIndexChange: (i) => reported = i),
      );
      await tester.pump();

      await tester.tap(find.byType(BeuiCylinderCarousel));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      // A single pump: the glide is dropped, so the value is set immediately.
      await tester.pump();
      expect(reported, 1);
    });

    testWidgets('auto-rotate is disabled under reduced motion', (tester) async {
      int? reported;
      await tester.pumpWidget(
        _app(
          reduce: true,
          autoRotate: true,
          onIndexChange: (i) => reported = i,
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(reported, isNull);
    });
  });

  testWidgets('rest-state golden (concave over convex)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 200,
                    child: BeuiCylinderCarousel(
                      itemSize: 120,
                      height: 200,
                      children: _balls(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: BeuiCylinderCarousel(
                      curve: BeuiCylinderCurve.convex,
                      itemSize: 120,
                      height: 200,
                      children: _balls(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/beui_cylinder_carousel.png'),
    );
  });
}
