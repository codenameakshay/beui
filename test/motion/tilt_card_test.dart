import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({bool reduce = false}) {
  Widget card = const BeuiTiltCard(child: SizedBox(width: 200, height: 200));
  if (reduce) {
    card = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: card,
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: Center(child: card)),
  );
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  return g;
}

/// The card's tilt matrix (the one carrying the perspective entry).
Matrix4 _tilt(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .firstWhere((t) => t.transform.storage[11] != 0)
    .transform;

/// Perspective weight of a card-centred point (z=0); larger = farther away.
/// w' = (4th row of M)·(x, y, 0, 1) = storage[3]·x + storage[7]·y + storage[15].
double _w(Matrix4 m, double x, double y) =>
    m.storage[3] * x + m.storage[7] * y + m.storage[15];

void main() {
  testWidgets('flat at rest', (tester) async {
    await tester.pumpWidget(_app());
    final m = _tilt(tester);
    expect(_w(m, 0, -100), closeTo(_w(m, 0, 100), 1e-9)); // top == bottom
    expect(_w(m, -100, 0), closeTo(_w(m, 100, 0), 1e-9)); // left == right
  });

  testWidgets('hovering the top recedes the top edge', (tester) async {
    await tester.pumpWidget(_app());
    final g = await _mouse(tester);
    final rect = tester.getRect(find.byType(BeuiTiltCard));
    await g.moveTo(rect.topCenter + const Offset(0, 6));
    await tester.pumpAndSettle();

    final m = _tilt(tester);
    expect(
      _w(m, 0, -100),
      greaterThan(_w(m, 0, 100)),
    ); // top farther than bottom
  });

  testWidgets('hovering the right recedes the right edge', (tester) async {
    await tester.pumpWidget(_app());
    final g = await _mouse(tester);
    final rect = tester.getRect(find.byType(BeuiTiltCard));
    await g.moveTo(rect.centerRight - const Offset(6, 0));
    await tester.pumpAndSettle();

    final m = _tilt(tester);
    expect(
      _w(m, 100, 0),
      greaterThan(_w(m, -100, 0)),
    ); // right farther than left
  });

  testWidgets('returns to flat after the pointer leaves', (tester) async {
    await tester.pumpWidget(_app());
    final g = await _mouse(tester);
    final rect = tester.getRect(find.byType(BeuiTiltCard));
    await g.moveTo(rect.topLeft + const Offset(6, 6));
    await tester.pumpAndSettle();
    expect(
      _w(_tilt(tester), 0, -100),
      isNot(closeTo(_w(_tilt(tester), 0, 100), 1e-6)),
    );

    await g.moveTo(const Offset(2, 2)); // off the card
    await tester.pumpAndSettle();
    final m = _tilt(tester);
    expect(_w(m, 0, -100), closeTo(_w(m, 0, 100), 1e-4)); // flat again
  });

  group(
    'glare gradient (source: `circle at gx% gy%, fg, transparent 50%`)',
    () {
      /// The glare's RadialGradient, and the box it paints into.
      (RadialGradient, Size) glare(WidgetTester tester) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(BeuiTiltCard),
            matching: find.byType(DecoratedBox),
          ),
        );
        final gradient =
            (box.decoration as BoxDecoration).gradient! as RadialGradient;
        return (gradient, tester.getSize(find.byType(BeuiTiltCard)));
      }

      /// Where the gradient reaches full transparency, in px from its centre.
      /// Flutter states `radius` as a fraction of the box's shortest side.
      double transparentAt(RadialGradient g, Size size) =>
          g.radius * math.min(size.width, size.height);

      /// CSS `circle` sizes to `farthest-corner`; `transparent 50%` puts the
      /// transparent stop at half that distance.
      double expectedAt(Size size, double gx, double gy) {
        final fx = math.max(gx, 1 - gx) * size.width;
        final fy = math.max(gy, 1 - gy) * size.height;
        return 0.5 * math.sqrt(fx * fx + fy * fy);
      }

      testWidgets('at rest it is half the centre-to-corner distance', (
        tester,
      ) async {
        await tester.pumpWidget(_app());
        final (g, size) = glare(tester);
        // A 200x200 card: 0.5 * sqrt(100^2 + 100^2) = 70.7px, NOT 0.7 * 200.
        expect(
          transparentAt(g, size),
          closeTo(expectedAt(size, 0.5, 0.5), 0.01),
        );
        expect(transparentAt(g, size), closeTo(70.71, 0.01));
      });

      testWidgets(
        'follows the cursor and re-sizes to the new farthest corner',
        (tester) async {
          await tester.pumpWidget(_app());
          final gesture = await _mouse(tester);
          final rect = tester.getRect(find.byType(BeuiTiltCard));
          // A quarter in from the top-left: the bottom-right corner is now the
          // farthest one, so the gradient grows.
          await gesture.moveTo(
            rect.topLeft + Offset(rect.width / 4, rect.height / 4),
          );
          await tester.pumpAndSettle();

          final (g, size) = glare(tester);
          expect(g.center, const Alignment(-0.5, -0.5));
          expect(
            transparentAt(g, size),
            closeTo(expectedAt(size, 0.25, 0.25), 0.01),
          );
          // 0.5 * sqrt(150^2 + 150^2) = 106.07 — larger than the at-rest 70.71.
          expect(transparentAt(g, size), closeTo(106.07, 0.01));
        },
      );
    },
  );

  testWidgets('reduced motion drops the tilt and glare', (tester) async {
    await tester.pumpWidget(_app(reduce: true));
    final g = await _mouse(tester);
    await g.moveTo(tester.getCenter(find.byType(BeuiTiltCard)));
    await tester.pumpAndSettle();

    // Material adds its own Transforms — assert no *perspective* tilt of ours.
    final tilts = tester
        .widgetList<Transform>(find.byType(Transform))
        .where((t) => t.transform.storage[11] != 0);
    expect(tilts, isEmpty);
    expect(find.byType(AnimatedOpacity), findsNothing); // no glare
  });
}
