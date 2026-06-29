import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({bool reduce = false}) {
  Widget card = const BeuiTiltCard(
    child: SizedBox(width: 200, height: 200),
  );
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
    expect(_w(m, 0, -100), greaterThan(_w(m, 0, 100))); // top farther than bottom
  });

  testWidgets('hovering the right recedes the right edge', (tester) async {
    await tester.pumpWidget(_app());
    final g = await _mouse(tester);
    final rect = tester.getRect(find.byType(BeuiTiltCard));
    await g.moveTo(rect.centerRight - const Offset(6, 0));
    await tester.pumpAndSettle();

    final m = _tilt(tester);
    expect(_w(m, 100, 0), greaterThan(_w(m, -100, 0))); // right farther than left
  });

  testWidgets('returns to flat after the pointer leaves', (tester) async {
    await tester.pumpWidget(_app());
    final g = await _mouse(tester);
    final rect = tester.getRect(find.byType(BeuiTiltCard));
    await g.moveTo(rect.topLeft + const Offset(6, 6));
    await tester.pumpAndSettle();
    expect(_w(_tilt(tester), 0, -100), isNot(closeTo(_w(_tilt(tester), 0, 100), 1e-6)));

    await g.moveTo(const Offset(2, 2)); // off the card
    await tester.pumpAndSettle();
    final m = _tilt(tester);
    expect(_w(m, 0, -100), closeTo(_w(m, 0, 100), 1e-4)); // flat again
  });

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
