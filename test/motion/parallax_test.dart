import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

/// A tall scroll view with the parallax target roughly a screen below the
/// fold, so scrolling carries it through the viewport.
Widget _scroller({required bool reduce, bool spring = false}) {
  return beuiTestApp(
    SizedBox(
      height: 600,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 800),
            BeuiParallax(
              speed: 0.3,
              spring: spring,
              child: const SizedBox(
                key: ValueKey('target'),
                height: 100,
                child: Center(child: Text('drift target')),
              ),
            ),
            const SizedBox(height: 800),
          ],
        ),
      ),
    ),
    reduce: reduce,
  );
}

double _driftY(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(BeuiParallax),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getTranslation()
    .y;

void main() {
  testWidgets('drift offset follows scroll as the target crosses the '
      'viewport', (tester) async {
    await tester.pumpWidget(_scroller(reduce: false));
    await tester.pump(); // anchor measurement (post-frame)
    await tester.pump();

    // Below the fold: drift starts near +travel (speed*100 = 30).
    final before = _driftY(tester);

    // Scroll the target up through the viewport.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pump();
    await tester.pump();
    final after = _driftY(tester);

    // As the element moves from below the viewport toward its top, drift
    // moves from +travel toward -travel — i.e. it decreases.
    expect(after, lessThan(before));
  });

  testWidgets('is static under reduced motion regardless of scroll', (
    tester,
  ) async {
    await tester.pumpWidget(_scroller(reduce: true));
    await tester.pump();
    await tester.pump();

    // No Transform at all — reduced motion renders the child unwrapped.
    expect(
      find.descendant(
        of: find.byType(BeuiParallax),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(BeuiParallax),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    expect(find.text('drift target'), findsOneWidget);
  });
}
