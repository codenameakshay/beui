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
  testWidgets(
    'price axis uses five source midpoint ticks and live-price scale',
    (tester) async {
      await tester.pumpWidget(beuiTestApp(_chart(lastPrice: 20)));
      await tester.pump();
      for (final tick in ['19.6', '17.05', '14.5', '11.95', '9.4']) {
        expect(find.text(tick), findsOneWidget);
      }
    },
  );

  testWidgets(
    'pointer crosshair tracks price, ignores axis, and clears on exit',
    (tester) async {
      String? changed;
      await tester.pumpWidget(
        beuiTestApp(_chart(onActiveIdChange: (id) => changed = id)),
      );
      final plot = tester.getRect(find.byType(BeuiCandlestickPlot));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset(plot.left - 5, plot.top));
      await mouse.moveTo(Offset(plot.left + 10, plot.top + 50));
      await tester.pump();
      expect(changed, 'a');
      final priceTag = find.byKey(const ValueKey('candle-pointer-price'));
      expect(priceTag, findsOneWidget);
      expect(tester.getCenter(priceTag).dy, closeTo(plot.top + 50, 1));
      await mouse.moveTo(Offset(plot.right - 5, plot.top + 80));
      await tester.pump();
      expect(changed, 'a');
      await mouse.moveTo(Offset(plot.left + 10, plot.bottom - 1));
      await tester.pump();
      expect(priceTag, findsNothing);
      await mouse.moveTo(Offset(plot.left - 5, plot.top));
      await tester.pump();
      expect(changed, isNull);
      await mouse.removePointer();
    },
  );

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
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
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

  testWidgets('last price is static text on the spring-positioned tag', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_chart(lastPrice: 12.75)));
    await tester.pump();
    expect(find.byType(BeuiChartTicker), findsNothing);
    expect(find.byType(BeuiNumberTicker), findsNothing);
    await tester.pump(const Duration(milliseconds: 220));
    final tag = find.byKey(const ValueKey('candle-last-price'));
    expect(tester.widget<Text>(tag).data, '12.75');
    expect(
      tester.getTopLeft(tag).dx,
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
    final firstBadgeCenter = tester
        .getCenter(find.byKey(const ValueKey('candle-last-price')))
        .dy;
    expect(firstBadgeCenter, closeTo(plotTop + 127.2, 2));

    await tester.pumpWidget(
      beuiTestApp(_chart(candles: candles, lastPrice: 107)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final animatedBadgeCenter = tester
        .getCenter(find.byKey(const ValueKey('candle-last-price')))
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
    await pumpFrames(tester, 20, frame: const Duration(milliseconds: 100));
    final shapes = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_CandleShapePainter',
    );
    expect(shapes, findsNWidgets(9));
    for (var index = 0; index < 9; index++) {
      final shape = shapes.at(index);
      expect(shape, index % 3 == 0 ? (paints..line()) : (paints..rect()));
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: shape, matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
        reason: 'Every candle wick, body and volume bar must be visible.',
      );
    }
    await expectLater(
      find.byType(BeuiCandlestickChart),
      matchesGoldenFile('goldens/beui_candlestick-chart.png'),
    );
  });
}
