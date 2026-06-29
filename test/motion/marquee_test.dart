import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  BeuiMarqueeDirection direction = BeuiMarqueeDirection.left,
  bool reduce = false,
  bool pauseOnHover = true,
}) {
  Widget marquee = SizedBox(
    width: 200,
    height: 60,
    child: BeuiMarquee(
      direction: direction,
      duration: const Duration(seconds: 2),
      pauseOnHover: pauseOnHover,
      fade: false,
      children: [
        for (final l in ['A', 'B', 'C', 'D'])
          SizedBox(width: 80, height: 40, child: Center(child: Text(l))),
      ],
    ),
  );
  if (reduce) {
    marquee = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: marquee,
    );
  }
  return MaterialApp(home: Scaffold(body: Center(child: marquee)));
}

double _x(WidgetTester t) => t.getTopLeft(find.text('A').first).dx;

/// Pumps past the measure/rebuild handshake so copies exist and run.
Future<void> _settleMeasure(WidgetTester t) async {
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('duplicates the track to fill and loop', (tester) async {
    await tester.pumpWidget(_app());
    await _settleMeasure(tester);
    expect(find.text('A'), findsAtLeastNWidgets(2));
  });

  testWidgets('scrolls left over time', (tester) async {
    await tester.pumpWidget(_app());
    await _settleMeasure(tester);
    final x0 = _x(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_x(tester), lessThan(x0)); // moved left
  });

  testWidgets('direction right scrolls the other way', (tester) async {
    await tester.pumpWidget(_app(direction: BeuiMarqueeDirection.right));
    await _settleMeasure(tester);
    final x0 = _x(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_x(tester), greaterThan(x0)); // moved right
  });

  testWidgets('pauses while hovered', (tester) async {
    await tester.pumpWidget(_app());
    await _settleMeasure(tester);

    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(tester.getCenter(find.byType(BeuiMarquee)));
    await tester.pump();

    final x0 = _x(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_x(tester), x0); // frozen on hover

    await g.moveTo(const Offset(5, 5)); // leave → resume
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_x(tester), lessThan(x0));
  });

  testWidgets('reduced motion holds it static', (tester) async {
    await tester.pumpWidget(_app(reduce: true));
    await _settleMeasure(tester);
    final x0 = _x(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_x(tester), x0); // no scroll
  });
}
