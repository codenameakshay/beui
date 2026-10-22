import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _snapshots = [
  BeuiLiquiditySnapshot(
    id: 't1',
    label: '14:00',
    price: 100.5,
    levels: [
      BeuiLiquidityLevel(price: 101, size: 20),
      BeuiLiquidityLevel(price: 100, size: 40),
    ],
  ),
  BeuiLiquiditySnapshot(
    id: 't2',
    label: '14:02',
    price: 100,
    levels: [
      BeuiLiquidityLevel(price: 101, size: 50),
      BeuiLiquidityLevel(price: 99, size: 10),
    ],
  ),
];

Widget _surface({bool reduce = false}) => beuiTestApp(
  const SizedBox(
    width: 640,
    height: 420,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: BeuiLiquidityHeatmap(
          snapshots: _snapshots,
          maxSize: 60,
          unit: 'SOL',
        ),
      ),
    ),
  ),
  reduce: reduce,
);

void main() {
  testWidgets('renders labeled discrete bands and missing-data semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_surface());
    expect(find.bySemanticsLabel('14:00, 101.00: 20 SOL'), findsOneWidget);
    expect(find.bySemanticsLabel('14:02, 99.00: 10 SOL'), findsOneWidget);
    expect(find.text('Resting liquidity · SOL'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('14:02, 100.00: No data')),
      isNotNull,
    );
    semantics.dispose();
  });

  testWidgets('Home and End move the inspected band and Escape clears it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_surface());
    await tester.tap(find.bySemanticsLabel('14:00, 101.00: 20 SOL'));
    await tester.pump();
    expect(find.text('14:00 · 101.00 · 20 SOL'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(find.text('14:02 · 99.00 · 10 SOL'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('14:02 · 99.00 · 10 SOL'), findsNothing);
    semantics.dispose();
  });

  testWidgets('hovering a cell activates it and reveals its size ticker', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    final cell = find.bySemanticsLabel('14:00, 101.00: 20 SOL');
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(cell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.byType(BeuiChartTicker), findsOneWidget);
    expect(
      tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker)).format(20),
      contains('SOL'),
    );
    await gesture.removePointer();
  });

  testWidgets('renders under reduced motion and matches rest-state golden', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(reduce: true));
    await tester.pump();
    expect(find.byType(BeuiLiquidityPlot), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/beui_liquidity_heatmap.png'),
    );
  });
}
