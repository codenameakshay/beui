import 'package:beui/beui.dart';
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

Widget _chart({String? activeId, ValueChanged<String?>? onActiveIdChange}) =>
    BeuiCandlestickChart(
      candles: _candles,
      activeId: activeId,
      onActiveIdChange: onActiveIdChange,
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
