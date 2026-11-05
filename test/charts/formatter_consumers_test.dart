import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('Sankey default formatter exposes source maximum precision', (
    tester,
  ) async {
    List<String>? formatted;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiSankeyChart(
          nodes: const [BeuiSankeyNode(id: 'one', label: 'One')],
          links: const [],
          child: Builder(
            builder: (context) {
              final model = BeuiSankeyChart.of(context);
              formatted = [
                for (final value in [100.0, 120.0, 2.0, 98.4, 1234.5, -.004])
                  model.formatValue(value),
              ];
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(formatted, ['100', '120', '2', '98.4', '1,234.5', '-0']);
  });

  testWidgets('candlestick legend keeps integer trailing zeroes', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCandlestickChart(
          candles: const [
            BeuiCandle(
              id: 'source-values',
              time: '12:00',
              open: 100,
              high: 120,
              low: 2,
              close: 98.4,
              volume: 1,
            ),
          ],
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('candle-legend-O'))).data,
      '100',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('candle-legend-H'))).data,
      '120',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('candle-legend-L'))).data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('candle-legend-C'))).data,
      '98.4',
    );
  });

  testWidgets('volume profile visible semantics keep grouped source values', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        BeuiVolumeProfile(
          valueArea: false,
          data: const [
            BeuiVolumeProfileBin.range(
              id: 'source-values',
              priceLow: 100,
              priceHigh: 120,
              volume: 98.4,
            ),
          ],
        ),
      ),
    );

    final bin = tester.getSemantics(
      find.bySemanticsLabel('Volume profile: inspect price level'),
    );
    expect(
      bin.value,
      '100 to 120. 98.4 units. 100.0% of total volume. Point of control',
    );
    semantics.dispose();
  });

  testWidgets('candlestick legend retains grouping and negative zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCandlestickChart(
          candles: const [
            BeuiCandle(
              id: 'grouped-negative-zero',
              time: '12:00',
              open: 1234.5,
              high: 2345.6,
              low: -.004,
              close: 100,
              volume: 1,
            ),
          ],
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('candle-legend-O'))).data,
      '1,234.5',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('candle-legend-H'))).data,
      '2,345.6',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('candle-legend-L'))).data,
      '-0',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('candle-legend-C'))).data,
      '100',
    );
  });

  for (final sample in [
    (
      bin: const BeuiVolumeProfileBin.range(
        id: 'grouped',
        priceLow: 1234.5,
        priceHigh: 2345.6,
        volume: 1234.5,
      ),
      value:
          '1,234.5 to 2,345.6. 1,234.5 units. 100.0% of total volume. Point of control',
    ),
    (
      bin: const BeuiVolumeProfileBin.range(
        id: 'negative-zero',
        priceLow: -.004,
        priceHigh: 2,
        volume: 2,
      ),
      value: '-0 to 2. 2 units. 100.0% of total volume. Point of control',
    ),
  ]) {
    testWidgets('volume default price and volume format ${sample.bin.id}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beuiTestApp(BeuiVolumeProfile(valueArea: false, data: [sample.bin])),
      );
      expect(
        tester
            .getSemantics(
              find.bySemanticsLabel('Volume profile: inspect price level'),
            )
            .value,
        sample.value,
      );
      semantics.dispose();
    });
  }

  testWidgets('Order Book keeps source fixed-two-decimal price formatting', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          width: 640,
          height: 420,
          child: BeuiOrderBook(
            bids: const [
              BeuiOrderBookLevel(price: 99, size: 2),
              BeuiOrderBookLevel(price: 98, size: 3),
            ],
            asks: const [BeuiOrderBookLevel(price: 101, size: 4)],
            defaultActiveLevel: const BeuiOrderBookActiveLevel(
              side: BeuiOrderBookSideKind.bid,
              price: 98,
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiOrderBookHeader(),
                BeuiOrderBookSide(side: BeuiOrderBookSideKind.ask),
                BeuiOrderBookSpread(),
                BeuiOrderBookSide(side: BeuiOrderBookSideKind.bid),
                BeuiOrderBookDepthSummary(),
                BeuiOrderBookBalance(),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(BeuiNumberTicker)).label,
      contains('100.00'),
    );
    expect(find.textContaining('Spread 2.00'), findsOneWidget);
    expect(find.textContaining('Avg 98.40'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('bid, 98.00'))),
      isNotNull,
    );
    semantics.dispose();
  });
}
