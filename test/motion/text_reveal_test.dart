import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduce = false}) {
  Widget body = child;
  if (reduce) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: Center(child: body)),
  );
}

/// The maximum vertical translate across every [Transform.translate] our reveal
/// emits — a proxy for "how far below the baseline the units still are".
double _maxRise(WidgetTester tester) {
  var max = 0.0;
  for (final t in tester.widgetList<Transform>(find.byType(Transform))) {
    final dy = t.transform.getTranslation().y.abs();
    if (dy > max) max = dy;
  }
  return max;
}

double _minOpacity(WidgetTester tester) {
  var min = 1.0;
  for (final o in tester.widgetList<Opacity>(find.byType(Opacity))) {
    if (o.opacity < min) min = o.opacity;
  }
  return min;
}

void main() {
  testWidgets('units start below and faded, then rise and fade in', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiTextReveal('Motion in words', style: TextStyle(fontSize: 32)),
      ),
    );

    // First frame after mount: units offset down and at low opacity.
    await tester.pump(); // schedule the post-frame forward()
    await tester.pump(const Duration(milliseconds: 16));
    final earlyRise = _maxRise(tester);
    final earlyOpacity = _minOpacity(tester);
    expect(earlyRise, greaterThan(1.0), reason: 'units should start raised');
    expect(earlyOpacity, lessThan(0.9), reason: 'units should start faded');

    // Let the whole stagger + spring settle.
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(_maxRise(tester), lessThan(0.5), reason: 'rest at baseline');
    expect(_minOpacity(tester), greaterThan(0.95), reason: 'fully opaque');
  });

  testWidgets('char split renders one unit per character', (tester) async {
    await tester.pumpWidget(
      _app(const BeuiTextReveal('abc', split: BeuiTextRevealSplit.char)),
    );
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('reduced motion drops the rise but keeps the fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiTextReveal('Motion in words', style: TextStyle(fontSize: 32)),
        reduce: true,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // No vertical movement under reduced motion...
    expect(_maxRise(tester), lessThan(0.5));
    // ...but the opacity transition is still mid-fade.
    expect(_minOpacity(tester), lessThan(1.0));

    await tester.pumpAndSettle();
    expect(_minOpacity(tester), greaterThan(0.95));
  });
}
