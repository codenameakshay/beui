import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Widget child = Center(
    child: SizedBox(
      width: 400,
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
      await tester.sendEventToBinding(
        pointer.scroll(const Offset(0, 300)),
      );
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
        _app(reduce: true, autoRotate: true, onIndexChange: (i) => reported = i),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(reported, isNull);
    });
  });

  testWidgets('rest-state golden (concave over convex)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
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
