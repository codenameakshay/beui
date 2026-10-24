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

Future<Path> _paintIrregularTrace(
  WidgetTester tester,
  List<double?> marketPrices,
) async {
  await tester.pumpWidget(
    beuiTestApp(
      SizedBox(
        width: marketPrices.length * 100.0 + 72,
        child: BeuiLiquidityHeatmap(
          formatPrice: (price) => price.toStringAsFixed(2),
          snapshots: [
            for (var i = 0; i < marketPrices.length; i++)
              BeuiLiquiditySnapshot(
                id: 't$i',
                label: 't$i',
                price: marketPrices[i],
                levels: const [
                  BeuiLiquidityLevel(price: 110, size: 20),
                  BeuiLiquidityLevel(price: 100, size: 40),
                  BeuiLiquidityLevel(price: 99, size: 10),
                ],
              ),
          ],
          child: const BeuiLiquidityPlot(),
        ),
      ),
      reduce: true,
    ),
  );
  final trace = find.descendant(
    of: find.byType(BeuiLiquidityPlot),
    matching: find.byType(CustomPaint),
  );
  expect(trace, findsOneWidget);
  final size = tester.getSize(trace);
  expect(size, Size(marketPrices.length * 100.0, 78));
  final canvas = TestRecordingCanvas();
  tester.widget<CustomPaint>(trace).painter!.paint(canvas, size);
  final draws = canvas.invocations.where(
    (record) => record.invocation.memberName == #drawPath,
  );
  expect(draws, hasLength(2));
  return draws.first.invocation.positionalArguments.first as Path;
}

void _expectTraceGeometry(Path actual, Path expected) {
  final actualContours = actual.computeMetrics().toList();
  final expectedContours = expected.computeMetrics().toList();
  expect(actualContours, hasLength(expectedContours.length));
  for (var i = 0; i < expectedContours.length; i++) {
    final actualContour = actualContours[i];
    final expectedContour = expectedContours[i];
    expect(actualContour.length, closeTo(expectedContour.length, .001));
    for (var sample = 0; sample <= 8; sample++) {
      final actualTangent = actualContour.getTangentForOffset(
        actualContour.length * sample / 8,
      )!;
      final expectedTangent = expectedContour.getTangentForOffset(
        expectedContour.length * sample / 8,
      )!;
      expect(
        actualTangent.position.dx,
        closeTo(expectedTangent.position.dx, .001),
      );
      expect(
        actualTangent.position.dy,
        closeTo(expectedTangent.position.dy, .001),
      );
      expect(actualTangent.angle, closeTo(expectedTangent.angle, .001));
    }
  }
}

void main() {
  for (final band in [(110.0, 13.0), (100.0, 39.0), (99.0, 65.0)]) {
    testWidgets('market price ${band.$1} aligns with its actual band center', (
      tester,
    ) async {
      final path = await _paintIrregularTrace(tester, [band.$1, band.$1]);
      _expectTraceGeometry(
        path,
        Path()
          ..moveTo(50, band.$2)
          ..lineTo(150, band.$2),
      );
    });
  }

  for (final point in [
    (107.5, 19.5),
    (102.5, 32.5),
    (99.75, 45.5),
    (99.25, 58.5),
  ]) {
    testWidgets(
      'market price ${point.$1} interpolates between adjacent band centers',
      (tester) async {
        final path = await _paintIrregularTrace(tester, [point.$1, point.$1]);
        _expectTraceGeometry(
          path,
          Path()
            ..moveTo(50, point.$2)
            ..lineTo(150, point.$2),
        );
      },
    );
  }

  testWidgets('trace draws straight segments between snapshot column centers', (
    tester,
  ) async {
    final path = await _paintIrregularTrace(tester, [110, 99, 110]);
    _expectTraceGeometry(
      path,
      Path()
        ..moveTo(50, 13)
        ..lineTo(150, 65)
        ..lineTo(250, 13),
    );
  });

  for (final gap in <(String, double?)>[
    ('missing', null),
    ('above the highest band', 111),
    ('below the lowest band', 98),
    ('NaN', double.nan),
    ('positive infinity', double.infinity),
    ('negative infinity', double.negativeInfinity),
  ]) {
    testWidgets('trace leaves a gap when market price is ${gap.$1}', (
      tester,
    ) async {
      final path = await _paintIrregularTrace(tester, [
        110,
        99,
        gap.$2,
        99,
        110,
      ]);
      _expectTraceGeometry(
        path,
        Path()
          ..moveTo(50, 13)
          ..lineTo(150, 65)
          ..moveTo(350, 65)
          ..lineTo(450, 13),
      );
    });
  }

  for (final invalidPrice in [
    ('NaN', double.nan),
    ('positive infinity', double.infinity),
    ('negative infinity', double.negativeInfinity),
  ]) {
    testWidgets(
      'default price formatter keeps cells inspectable with ${invalidPrice.$1} market price',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          beuiTestApp(
            SizedBox(
              width: 640,
              child: BeuiLiquidityHeatmap(
                snapshots: [
                  BeuiLiquiditySnapshot(
                    id: 'invalid',
                    label: '14:00',
                    price: invalidPrice.$2,
                    levels: const [
                      BeuiLiquidityLevel(price: 101, size: 20),
                      BeuiLiquidityLevel(price: 100, size: 40),
                    ],
                  ),
                  _snapshots.first,
                ],
                unit: 'SOL',
                child: const BeuiLiquidityPlot(),
              ),
            ),
            reduce: true,
          ),
        );
        expect(tester.takeException(), isNull);
        final invalidCell = find.bySemanticsLabel('14:00, 100.00: 40 SOL');
        expect(invalidCell, findsNWidgets(2));
        await tester.tap(invalidCell.first);
        await tester.pump();
        expect(find.text('14:00 · 100.00 · 40 SOL'), findsNothing);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(invalidCell.first));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(find.text('14:00 · 100.00'), findsOneWidget);
        expect(find.text('14:00 · 100.00 · 40 SOL'), findsNothing);
        expect(find.textContaining('Market '), findsNothing);

        await gesture.moveTo(tester.getCenter(invalidCell.last));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(find.text('14:00 · 100.00'), findsOneWidget);
        expect(find.text('14:00 · 100.00 · 40 SOL'), findsNothing);
        expect(find.text('Market 100.50'), findsOneWidget);
        await gesture.removePointer();
        semantics.dispose();
      },
    );
  }

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
    expect(
      tester
          .widgetList<BeuiChartTooltip>(find.byType(BeuiChartTooltip))
          .where((tooltip) => tooltip.open == true)
          .single
          .content,
      isA<BeuiChartTooltipCard>(),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(
      tester
          .widgetList<BeuiChartTooltip>(find.byType(BeuiChartTooltip))
          .where((tooltip) => tooltip.open == true)
          .map((tooltip) => (tooltip.content as BeuiChartTooltipCard).title),
      ['14:02 · 101.00'],
    );
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
