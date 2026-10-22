import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

const _candles = [
  BeuiCandle(
    id: 'a',
    time: '12:00',
    open: 10,
    high: 13,
    low: 9,
    close: 12,
    volume: 40,
  ),
  BeuiCandle(
    id: 'b',
    time: '12:05',
    open: 12,
    high: 14,
    low: 11,
    close: 11,
    volume: 55,
  ),
  BeuiCandle(
    id: 'c',
    time: '12:10',
    open: 11,
    high: 15,
    low: 10,
    close: 14,
    volume: 62,
  ),
];

Widget _chart({
  List<BeuiCandle> candles = _candles,
  String? activeId,
  ValueChanged<String?>? onActiveIdChange,
  double? lastPrice,
}) => BeuiCandlestickChart(
  candles: candles,
  activeId: activeId,
  onActiveIdChange: onActiveIdChange,
  lastPrice: lastPrice,
  label: 'Test OHLC chart',
);

void main() {
  testWidgets('renders plot, live OHLC readout and accessible slider', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(beuiTestApp(_chart()));
    await tester.pump();
    expect(find.byType(BeuiCandlestickPlot), findsOneWidget);
    expect(find.text('12:10'), findsOneWidget);
    expect(find.bySemanticsLabel('Test OHLC chart'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('supports default active id and controlled callbacks', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCandlestickChart(
          candles: _candles,
          defaultActiveId: 'a',
          onActiveIdChange: (id) => changed = id,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('12:00'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'b');
    await tester.pumpWidget(
      beuiTestApp(
        _chart(activeId: 'c', onActiveIdChange: (id) => changed = id),
      ),
    );
    await tester.pump();
    expect(find.text('12:10'), findsOneWidget);
  });

  testWidgets('last price is an animated badge on the plot', (tester) async {
    await tester.pumpWidget(beuiTestApp(_chart(lastPrice: 12.75)));
    await tester.pump();
    expect(find.byType(BeuiChartTicker), findsOneWidget);
    expect(find.byType(BeuiNumberTicker), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 220));
    final ticker = tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker));
    expect(ticker.format(ticker.value), '12.75');
    expect(
      tester.getTopLeft(find.byType(BeuiChartTicker)).dx,
      greaterThan(tester.getRect(find.byType(BeuiCandlestickPlot)).left),
    );
    expect(find.textContaining('Last '), findsNothing);
  });

  testWidgets('first live price appears at its value without flying in', (
    tester,
  ) async {
    const candles = [
      BeuiCandle(
        id: 'only',
        time: '12:00',
        open: 104,
        high: 110,
        low: 100,
        close: 106,
        volume: 40,
      ),
    ];
    await tester.pumpWidget(beuiTestApp(_chart(candles: candles)));
    await tester.pump();
    await tester.pumpWidget(
      beuiTestApp(_chart(candles: candles, lastPrice: 105)),
    );
    await tester.pump();

    final plotTop = tester.getTopLeft(find.byType(BeuiCandlestickPlot)).dy;
    final firstBadgeCenter = tester.getCenter(find.byType(BeuiChartTicker)).dy;
    expect(firstBadgeCenter, closeTo(plotTop + 124.8, 2));

    await tester.pumpWidget(
      beuiTestApp(_chart(candles: candles, lastPrice: 107)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final animatedBadgeCenter = tester
        .getCenter(find.byType(BeuiChartTicker))
        .dy;
    expect(animatedBadgeCenter, lessThan(firstBadgeCenter));
    expect(animatedBadgeCenter, greaterThan(plotTop + 82));
  });

  testWidgets('tooltip card retains its 240px width cap', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiChartTooltipCard(
          title: 'Price details',
          lines: [List.filled(80, 'long').join(' ')],
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(BeuiChartTooltipCard)).width,
      lessThanOrEqualTo(240),
    );
  });

  testWidgets('mouse hover across the plot activates the candle under it', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(_chart(onActiveIdChange: (id) => changed = id)),
    );
    final plot = tester.getRect(find.byType(BeuiCandlestickPlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(plot.left + 20, plot.center.dy));
    await mouse.moveTo(Offset(plot.left + plot.width * .2, plot.center.dy));
    await tester.pump();
    expect(changed, 'a');
    await mouse.moveTo(Offset(plot.left + plot.width * .7, plot.center.dy));
    await tester.pump();
    expect(changed, 'c');
    await mouse.removePointer();
  });

  testWidgets('reduced motion renders the current candle state immediately', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_chart(activeId: 'b'), reduce: true));
    await tester.pump();
    expect(find.text('12:05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      beuiTestApp(
        const RepaintBoundary(
          child: BeuiCandlestickChart(
            candles: _candles,
            label: 'Candlestick chart',
          ),
        ),
        width: 640,
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BeuiCandlestickChart),
      matchesGoldenFile('goldens/beui_candlestick-chart.png'),
    );
  });
}
