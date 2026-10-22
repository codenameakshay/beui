import 'dart:math' as math;
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the candlestick chart.
Widget candlestickChartDemo(BuildContext context) =>
    const _CandlestickChartDemo();

class _CandlestickChartDemo extends StatelessWidget {
  const _CandlestickChartDemo();
  @override
  Widget build(BuildContext context) {
    const step = 300;
    const start = 12 * 3600;
    String two(int n) => n.toString().padLeft(2, '0');
    String label(int seconds) =>
        '${two((seconds ~/ 3600) % 24)}:${two((seconds % 3600) ~/ 60)}';
    var close = 2380.0;
    final candles = <BeuiCandle>[];
    for (var i = 0; i < 48; i++) {
      final open = close;
      close = open * (1 + math.sin(i * .7) * .004 + math.cos(i * .23) * .003);
      final reach =
          (close - open).abs() * .6 + 1.5 + math.sin(i * 1.9).abs() * 3;
      final time = start + i * step;
      candles.add(
        BeuiCandle(
          id: '$time',
          time: label(time),
          open: open,
          close: close,
          high: math.max(open, close) + reach * math.cos(i * 1.3).abs(),
          low: math.min(open, close) - reach * math.sin(i * .9).abs(),
          volume: 120 + math.sin(i * .6).abs() * 420,
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: BeuiCandlestickChart(
          candles: candles,
          lastPrice: candles.last.close,
          label: 'Simulated ETH / USD, 5 minute candles',
          formatPrice: (v) =>
              '\$${beuiChartFormatNumber(v, maximumFractionDigits: 2)}',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ETH / USD · 5m'),
              SizedBox(height: 8),
              BeuiCandlestickLegend(),
              SizedBox(height: 12),
              BeuiCandlestickPlot(height: 320),
            ],
          ),
        ),
      ),
    );
  }
}
