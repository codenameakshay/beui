import 'dart:async';
import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Preview for the order book.
Widget orderBookDemo(BuildContext context) => const _OrderBookDemo();

class _OrderBookDemo extends StatefulWidget {
  const _OrderBookDemo();

  @override
  State<_OrderBookDemo> createState() => _OrderBookDemoState();
}

class _OrderBookDemoState extends State<_OrderBookDemo> {
  static const _asks = [284, 574, 363, 278, 1800, 2200, 1100, 1200, 782];
  static const _bids = [194, 543, 314, 592, 715, 744, 789, 735, 1100];
  bool _playing = true;
  int _tick = 0;
  double? _selected;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 950), (_) {
      if (_playing &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        setState(() => _tick++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<BeuiOrderBookLevel> _side(List<int> sizes, int direction) => [
    for (var i = 0; i < sizes.length; i++)
      BeuiOrderBookLevel(
        price: double.parse(
          (245.85 + direction * (i + 1) * .15).toStringAsFixed(2),
        ),
        size: _size(sizes[i], i, direction),
      ),
  ];

  double _size(int size, int i, int direction) {
    final phase = (i + (direction == 1 ? 1 : 0)) % 3;
    final lastUpdate = _tick - ((_tick + phase) % 3);
    return lastUpdate <= 0
        ? size.toDouble()
        : (size * (1 + math.sin(lastUpdate * 1.3 + i * 2.1 + direction) * .32))
              .roundToDouble();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'SOL / USD',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              const Text('SIMULATED', style: TextStyle(fontSize: 9)),
              const Spacer(),
              BeuiButton(
                variant: BeuiButtonVariant.ghost,
                size: BeuiButtonSize.sm,
                onPressed: () => setState(() => _playing = !_playing),
                child: Text(_playing ? 'Pause' : 'Resume'),
              ),
              BeuiButton(
                variant: BeuiButtonVariant.ghost,
                size: BeuiButtonSize.sm,
                onPressed: () => setState(() {
                  _playing = false;
                  _tick++;
                }),
                child: const Text('Step'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BeuiOrderBook(
            bids: _side(_bids, -1),
            asks: _side(_asks, 1),
            baseSymbol: 'SOL',
            quoteSymbol: 'USD',
            label: 'Simulated SOL / USD order book',
            onLevelSelect: (level, _) =>
                setState(() => _selected = level.price),
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
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _selected == null
                  ? 'Click a price to use it, for example in an order ticket.'
                  : 'Selected ${_selected!.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontSize: 12,
                color: BeuiColors.resolve(context).mutedForeground,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
