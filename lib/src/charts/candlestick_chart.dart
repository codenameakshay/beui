/// OHLC candles with volume, a last-price line, and a crosshair readout.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/animated_number.dart';
import '../theme/beui_colors.dart';
import '_shared.dart';

/// One OHLC observation. [time] is the display label used by the crosshair.
@immutable
class BeuiCandle {
  /// Creates a candle.
  const BeuiCandle({
    required this.id,
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// Stable identity across streaming updates.
  final String id;

  /// Axis and readout label, such as `14:05`.
  final String time;

  /// Opening price.
  final double open;

  /// Highest price.
  final double high;

  /// Lowest price.
  final double low;

  /// Closing price.
  final double close;

  /// Traded volume.
  final double volume;
}

/// Composable candlestick chart root.
class BeuiCandlestickChart extends StatefulWidget {
  /// Creates an OHLC chart.
  const BeuiCandlestickChart({
    required this.candles,
    super.key,
    this.lastPrice,
    this.activeId,
    this.defaultActiveId,
    this.onActiveIdChange,
    this.formatPrice,
    this.formatVolume,
    this.label = 'Candlestick chart',
    this.child,
  });

  /// Candle history, ordered from oldest to newest.
  final List<BeuiCandle> candles;

  /// Optional live-price guide.
  final double? lastPrice;

  /// Controlled crosshair id.
  final String? activeId;

  /// Initial crosshair id when uncontrolled.
  final String? defaultActiveId;

  /// Notifies crosshair changes.
  final ValueChanged<String?>? onActiveIdChange;

  /// Price formatter.
  final String Function(double value)? formatPrice;

  /// Volume formatter.
  final String Function(double value)? formatVolume;

  /// Accessible chart name.
  final String label;

  /// Custom chart composition; defaults to legend and plot.
  final Widget? child;

  @override
  State<BeuiCandlestickChart> createState() => _BeuiCandlestickChartState();
}

class _BeuiCandlestickChartState extends State<BeuiCandlestickChart>
    with BeuiChartActiveState<BeuiCandlestickChart> {
  @override
  String? get widgetActiveId => widget.activeId;
  @override
  String? get widgetDefaultActiveId => widget.defaultActiveId;
  @override
  ValueChanged<String?>? get widgetOnActiveChange => widget.onActiveIdChange;
  @override
  Iterable<String> get knownIds => widget.candles.map((c) => c.id);

  String Function(double) get price =>
      widget.formatPrice ??
      (v) => beuiChartFormatNumber(v, maximumFractionDigits: 2);
  String Function(double) get volume =>
      widget.formatVolume ?? (v) => beuiChartFormatNumber(v, compact: true);

  @override
  void initState() {
    super.initState();
    initActive();
  }

  @override
  Widget build(BuildContext context) => _CandleScope(
    state: this,
    child: BeuiChartFrame(
      label: widget.label,
      child:
          widget.child ??
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeuiCandlestickLegend(),
              SizedBox(height: 12),
              BeuiCandlestickPlot(),
            ],
          ),
    ),
  );
}

class _CandleScope extends InheritedWidget {
  const _CandleScope({required this.state, required super.child});
  final _BeuiCandlestickChartState state;
  static _BeuiCandlestickChartState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_CandleScope>();
    assert(
      scope != null,
      'Candlestick parts must be inside BeuiCandlestickChart.',
    );
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_CandleScope old) => true;
}

/// Displays the active candle OHLC and volume values.
class BeuiCandlestickLegend extends StatelessWidget {
  /// Creates the live readout.
  const BeuiCandlestickLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final state = _CandleScope.of(context);
    final list = state.widget.candles;
    if (list.isEmpty) return const SizedBox.shrink();
    final candle =
        list.where((c) => c.id == state.activeId).firstOrNull ?? list.last;
    final colors = BeuiColors.resolve(context);
    final tone = candle.close >= candle.open
        ? colors.success
        : colors.destructive;
    final change = candle.open == 0
        ? 0.0
        : (candle.close - candle.open) / candle.open * 100;
    return BeuiChartTooltip(
      enabled: state.activeId != null,
      content: BeuiChartTooltipCard(
        title: candle.time,
        lines: [
          'O ${state.price(candle.open)}  H ${state.price(candle.high)}',
          'L ${state.price(candle.low)}  C ${state.price(candle.close)}',
          'Vol ${state.volume(candle.volume)}',
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            candle.time,
            style: TextStyle(color: colors.mutedForeground, fontSize: 12),
          ),
          for (final entry in <(String, double)>[
            ('O', candle.open),
            ('H', candle.high),
            ('L', candle.low),
            ('C', candle.close),
          ])
            Text(
              '${entry.$1} ${state.price(entry.$2)}',
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          Text(
            'Vol ${state.volume(candle.volume)}',
            style: TextStyle(color: colors.mutedForeground, fontSize: 12),
          ),
          if (state.widget.lastPrice != null)
            BeuiAnimatedNumber(
              value: state.widget.lastPrice!,
              format: (v) => 'Last ${state.price(v.toDouble())}',
              style: TextStyle(color: colors.foreground, fontSize: 12),
            ),
          Text(
            beuiChartSignedPercent(change),
            style: TextStyle(color: tone, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Interactive candlestick plot with volume bars and a keyboard crosshair.
class BeuiCandlestickPlot extends StatelessWidget {
  /// Creates the plot.
  const BeuiCandlestickPlot({super.key, this.height = 320});

  /// Plot height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final state = _CandleScope.of(context);
    final candles = state.widget.candles;
    final colors = BeuiColors.resolve(context);
    final lows = [
      ...candles.map((c) => c.low),
      if (state.widget.lastPrice != null) state.widget.lastPrice!,
    ];
    final highs = [
      ...candles.map((c) => c.high),
      if (state.widget.lastPrice != null) state.widget.lastPrice!,
    ];
    final minPrice = lows.isEmpty ? 0.0 : lows.reduce(math.min);
    final maxPrice = highs.isEmpty ? 1.0 : highs.reduce(math.max);
    final pad = math.max((maxPrice - minPrice) * .08, maxPrice.abs() * .0005);
    final activeIndex = candles.indexWhere((c) => c.id == state.activeId);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, box) {
          const gutter = 58.0;
          final plotWidth = math.max(0.0, box.maxWidth - gutter);
          final range = maxPrice - minPrice + pad * 2;
          final priceHeight = height * .78;
          final index = activeIndex < 0 ? candles.length - 1 : activeIndex;
          final candle = candles.isEmpty
              ? null
              : candles[index.clamp(0, candles.length - 1)];
          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              final ids = candles.map((c) => c.id).toList();
              if (ids.isEmpty) return KeyEventResult.ignored;
              final key = event.logicalKey;
              var next = index;
              if (key == LogicalKeyboardKey.escape) {
                state.setActiveId(null);
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.home) {
                next = 0;
              } else if (key == LogicalKeyboardKey.end) {
                next = ids.length - 1;
              } else if (key == LogicalKeyboardKey.arrowLeft) {
                next = (index - 1).clamp(0, ids.length - 1);
              } else if (key == LogicalKeyboardKey.arrowRight) {
                next = (index + 1).clamp(0, ids.length - 1);
              } else {
                return KeyEventResult.ignored;
              }
              state.setActiveId(ids[next]);
              return KeyEventResult.handled;
            },
            child: Semantics(
              slider: true,
              focusable: true,
              label: state.widget.label,
              value: candle == null
                  ? null
                  : '${candle.time}: open ${state.price(candle.open)}, high ${state.price(candle.high)}, low ${state.price(candle.low)}, close ${state.price(candle.close)}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (event) {
                  if (candles.isNotEmpty && plotWidth > 0) {
                    final i =
                        (event.localPosition.dx / plotWidth * candles.length)
                            .floor()
                            .clamp(0, candles.length - 1);
                    state.setActiveId(candles[i].id);
                  }
                },
                child: BeuiChartSpring(
                  value: candles.isEmpty ? 0 : candles.last.close,
                  builder: (context, animatedClose) {
                    final animatedCandles = candles.isEmpty
                        ? candles
                        : [
                            ...candles.take(candles.length - 1),
                            BeuiCandle(
                              id: candles.last.id,
                              time: candles.last.time,
                              open: candles.last.open,
                              high: math.max(candles.last.high, animatedClose),
                              low: math.min(candles.last.low, animatedClose),
                              close: animatedClose,
                              volume: candles.last.volume,
                            ),
                          ];
                    return CustomPaint(
                      painter: _CandlePainter(
                        candles: animatedCandles,
                        width: plotWidth,
                        height: height,
                        priceHeight: priceHeight,
                        min: minPrice - pad,
                        range: range,
                        maxVolume: candles.fold<double>(
                          1,
                          (m, c) => math.max(m, c.volume),
                        ),
                        lastPrice: state.widget.lastPrice,
                        activeIndex: activeIndex,
                        colors: colors,
                      ),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.candles,
    required this.width,
    required this.height,
    required this.priceHeight,
    required this.min,
    required this.range,
    required this.maxVolume,
    required this.lastPrice,
    required this.activeIndex,
    required this.colors,
  });
  final List<BeuiCandle> candles;
  final double width, height, priceHeight, min, range, maxVolume;
  final double? lastPrice;
  final int activeIndex;
  final BeuiColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final plotW = width;
    final slot = candles.isEmpty ? 0.0 : plotW / candles.length;
    double y(double p) =>
        (1 - (p - min) / (range == 0 ? 1 : range)) * priceHeight;
    final grid = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final yy = priceHeight * i / 5;
      canvas.drawLine(Offset.zero.translate(0, yy), Offset(plotW, yy), grid);
    }
    final volumeMax = maxVolume <= 0 ? 1 : maxVolume;
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = (i + .5) * slot;
      final up = c.close >= c.open;
      final color = up ? colors.success : colors.destructive;
      final paint = Paint()..color = color;
      final top = y(math.max(c.open, c.close));
      final bottom = y(math.min(c.open, c.close));
      canvas.drawLine(
        Offset(x, y(c.high)),
        Offset(x, y(c.low)),
        paint..strokeWidth = 1,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          x - math.max(1.0, slot * .3),
          top,
          x + math.max(1.0, slot * .3),
          math.max(top + 1, bottom),
        ),
        paint,
      );
      final vh = c.volume / volumeMax * height * .16;
      canvas.drawRect(
        Rect.fromLTRB(
          x - math.max(1.0, slot * .3),
          height - vh,
          x + math.max(1.0, slot * .3),
          height,
        ),
        paint..color = color.withValues(alpha: .35),
      );
      if (i == activeIndex) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, height),
          Paint()..color = colors.foreground.withValues(alpha: .35),
        );
      }
    }
    if (lastPrice != null) {
      final p = Paint()
        ..color = colors.foreground.withValues(alpha: .5)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(0, y(lastPrice!)),
        Offset(plotW, y(lastPrice!)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.candles != candles ||
      old.width != width ||
      old.lastPrice != lastPrice ||
      old.activeIndex != activeIndex;
}
