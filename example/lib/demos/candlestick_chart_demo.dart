import 'dart:async';
import 'dart:math' as math;
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the candlestick chart.
Widget candlestickChartDemo(BuildContext context) =>
    const _CandlestickChartDemo();

class _CandlestickChartDemo extends StatefulWidget {
  const _CandlestickChartDemo();

  @override
  State<_CandlestickChartDemo> createState() => _CandlestickChartDemoState();
}

class _CandlestickChartDemoState extends State<_CandlestickChartDemo> {
  static const _step = 300;
  static const _start = 12 * 3600;
  late List<BeuiCandle> _candles = _seed();
  int _tick = 0;
  bool _playing = true;
  Timer? _timer;

  static String _label(int seconds) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two((seconds ~/ 3600) % 24)}:${two((seconds % 3600) ~/ 60)}';
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_playing &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        setState(_advance);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _advance() {
    _tick++;
    final last = _candles.last;
    final price =
        last.close *
        (1 + math.sin(_tick * 1.7) * .0012 + math.cos(_tick * .6) * .0006);
    final updated = BeuiCandle(
      id: last.id,
      time: last.time,
      open: last.open,
      close: price,
      high: math.max(last.high, price),
      low: math.min(last.low, price),
      volume: last.volume + 12 + math.sin(_tick).abs() * 30,
    );
    _candles = [..._candles.take(_candles.length - 1), updated];
    if (_tick % 8 == 0) {
      final start = int.parse(last.id) + _step;
      _candles = [
        ..._candles.skip(1),
        BeuiCandle(
          id: '$start',
          time: _label(start),
          open: price,
          high: price,
          low: price,
          close: price,
          volume: 0,
        ),
      ];
    }
  }

  static List<BeuiCandle> _seed() {
    var close = 2380.0;
    final candles = <BeuiCandle>[];
    for (var i = 0; i < 48; i++) {
      final open = close;
      close = open * (1 + math.sin(i * .7) * .004 + math.cos(i * .23) * .003);
      final reach =
          (close - open).abs() * .6 + 1.5 + math.sin(i * 1.9).abs() * 3;
      final time = _start + i * _step;
      candles.add(
        BeuiCandle(
          id: '$time',
          time: _label(time),
          open: open,
          close: close,
          high: math.max(open, close) + reach * math.cos(i * 1.3).abs(),
          low: math.min(open, close) - reach * math.sin(i * .9).abs(),
          volume: 120 + math.sin(i * .6).abs() * 420,
        ),
      );
    }
    return candles;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Text(
                    'ETH / USD · 5m',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: BeuiColors.resolve(context).border,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'SIMULATED',
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.5,
                          letterSpacing: .45,
                          fontWeight: FontWeight.w400,
                          color: BeuiColors.resolve(context).mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  BeuiButton(
                    variant: BeuiButtonVariant.ghost,
                    size: BeuiButtonSize.sm,
                    onPressed: () => setState(() => _playing = !_playing),
                    child: Text(_playing ? 'Pause' : 'Resume'),
                  ),
                  const SizedBox(width: 8),
                  BeuiButton(
                    variant: BeuiButtonVariant.ghost,
                    size: BeuiButtonSize.sm,
                    onPressed: () => setState(() {
                      _playing = false;
                      _advance();
                    }),
                    child: const Text('Step'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BeuiCandlestickChart(
              candles: _candles,
              lastPrice: _candles.last.close,
              label: 'Simulated ETH / USD, 5 minute candles',
              formatPrice: (v) =>
                  beuiChartFormatNumber(v, maximumFractionDigits: 2),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BeuiCandlestickLegend(),
                  SizedBox(height: 16),
                  BeuiCandlestickPlot(height: 320),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
