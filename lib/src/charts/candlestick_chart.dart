/// OHLC candles with volume, a last-price line, and a crosshair readout.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 16 / 12,
        fontFeatures: [FontFeature.tabularFigures()],
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
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.$1} ',
                    style: TextStyle(color: colors.mutedForeground),
                  ),
                  TextSpan(
                    text: state.price(entry.$2),
                    style: TextStyle(color: tone),
                  ),
                ],
              ),
            ),
          Text(
            'Vol ${state.volume(candle.volume)}',
            style: TextStyle(color: colors.mutedForeground, fontSize: 12),
          ),
          Text(
            beuiChartSignedPercent(change, digits: 2),
            style: TextStyle(color: tone, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Interactive candlestick plot with volume bars and a keyboard crosshair.
class BeuiCandlestickPlot extends StatefulWidget {
  /// Creates the plot.
  const BeuiCandlestickPlot({super.key, this.height = 320});

  /// Plot height.
  final double height;

  @override
  State<BeuiCandlestickPlot> createState() => _BeuiCandlestickPlotState();
}

class _BeuiCandlestickPlotState extends State<BeuiCandlestickPlot> {
  double? _pointerY;
  final _focus = FocusNode();

  double get height => widget.height;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

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
    final pad = math.max(
      math.max((maxPrice - minPrice) * .08, maxPrice * .0005),
      .0001,
    );
    final activeIndex = candles.indexWhere((c) => c.id == state.activeId);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, box) {
          const gutter = 64.0;
          final plotWidth = math.max(0.0, box.maxWidth - gutter);
          final range = maxPrice - minPrice + pad * 2;
          final priceHeight = height * .82 - 8;
          double y(double price) =>
              (maxPrice + pad - price) / range * priceHeight;
          final ticks = List.generate(
            5,
            (i) => maxPrice + pad - range * (i + .5) / 5,
          );
          void inspect(Offset position) {
            if (candles.isEmpty || plotWidth <= 0 || position.dx > plotWidth) {
              return;
            }
            final i = (position.dx / plotWidth * candles.length).floor().clamp(
              0,
              candles.length - 1,
            );
            state.setActiveId(candles[i].id);
            setState(
              () => _pointerY = position.dy <= priceHeight ? position.dy : null,
            );
          }

          final index = activeIndex < 0 ? candles.length - 1 : activeIndex;
          final candle = candles.isEmpty
              ? null
              : candles[index.clamp(0, candles.length - 1)];
          return Focus(
            focusNode: _focus,
            onFocusChange: (focused) {
              if (!focused) {
                state.setActiveId(null);
                setState(() => _pointerY = null);
              }
            },
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
                setState(() => _pointerY = null);
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
              setState(() => _pointerY = null);
              return KeyEventResult.handled;
            },
            child: Semantics(
              slider: true,
              focusable: true,
              label: state.widget.label,
              value: candle == null
                  ? null
                  : '${candle.time}: open ${state.price(candle.open)}, high ${state.price(candle.high)}, low ${state.price(candle.low)}, close ${state.price(candle.close)}',
              child: MouseRegion(
                cursor: SystemMouseCursors.precise,
                onEnter: (event) => inspect(event.localPosition),
                onHover: (event) => inspect(event.localPosition),
                onExit: (_) {
                  state.setActiveId(null);
                  setState(() => _pointerY = null);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (event) {
                    _focus.requestFocus();
                    inspect(event.localPosition);
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
                                high: math.max(
                                  candles.last.high,
                                  animatedClose,
                                ),
                                low: math.min(candles.last.low, animatedClose),
                                close: animatedClose,
                                volume: candles.last.volume,
                              ),
                            ];
                      return BeuiChartSpring(
                        key: ValueKey(state.widget.lastPrice == null),
                        value: state.widget.lastPrice ?? 0,
                        builder: (context, animatedLastPrice) {
                          final priceY =
                              state.widget.lastPrice == null || range == 0
                              ? 0.0
                              : (1 -
                                        (animatedLastPrice - (minPrice - pad)) /
                                            range) *
                                    priceHeight;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                size: Size(plotWidth, height),
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
                                  lastPrice: state.widget.lastPrice == null
                                      ? null
                                      : animatedLastPrice,
                                  activeIndex: activeIndex,
                                  pointerY: _pointerY,
                                  colors: colors,
                                ),
                              ),
                              for (final tick in ticks)
                                Positioned(
                                  right: 4,
                                  top: y(tick) - 8,
                                  child: IgnorePointer(
                                    child: Text(
                                      state.price(tick),
                                      style: TextStyle(
                                        color: colors.mutedForeground,
                                        fontSize: 12,
                                        height: 16 / 12,
                                        fontFamily: 'monospace',
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (state.widget.lastPrice != null)
                                Positioned(
                                  right: 0,
                                  top: priceY - 11,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.foreground,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      child: BeuiChartTicker(
                                        value: state.widget.lastPrice!,
                                        format: (v) =>
                                            state.price(v.toDouble()),
                                        style: TextStyle(
                                          color: colors.background,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_pointerY != null)
                                Positioned(
                                  right: 0,
                                  top: _pointerY! - 10,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      key: const ValueKey(
                                        'candle-pointer-price',
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.muted,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          state.price(
                                            maxPrice +
                                                pad -
                                                _pointerY! /
                                                    priceHeight *
                                                    range,
                                          ),
                                          style: TextStyle(
                                            color: colors.foreground,
                                            fontSize: 12,
                                            height: 16 / 12,
                                            fontFamily: 'monospace',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
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
    required this.pointerY,
    required this.colors,
  });
  final List<BeuiCandle> candles;
  final double width, height, priceHeight, min, range, maxVolume;
  final double? lastPrice;
  final int activeIndex;
  final double? pointerY;
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
    for (var i = 0; i < 5; i++) {
      final yy = priceHeight * (i + .5) / 5;
      for (var x = 0.0; x < plotW; x += 8) {
        canvas.drawLine(
          Offset(x, yy),
          Offset(math.min(x + 2, plotW), yy),
          grid,
        );
      }
    }
    final volumeMax = maxVolume <= 0 ? 1 : maxVolume;
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = (i + .5) * slot;
      final up = c.close >= c.open;
      final color = (up ? const Color(0xFF00BC7D) : const Color(0xFFFF2056))
          .withValues(alpha: activeIndex >= 0 && activeIndex != i ? .45 : 1);
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
          x - math.max(1.0, slot * .62) / 2,
          top,
          x + math.max(1.0, slot * .62) / 2,
          math.max(top + 1, bottom),
        ),
        paint,
      );
      final vh = math.max(.5, c.volume / volumeMax * height * .18);
      canvas.drawRect(
        Rect.fromLTRB(
          x - math.max(1.0, slot * .62) / 2,
          height - vh,
          x + math.max(1.0, slot * .62) / 2,
          height,
        ),
        paint..color = color.withValues(alpha: color.a * .28),
      );
      if (i == activeIndex) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, height),
          Paint()..color = colors.foreground.withValues(alpha: .3),
        );
      }
    }
    if (pointerY != null) {
      canvas.drawLine(
        Offset(0, pointerY!),
        Offset(plotW, pointerY!),
        Paint()..color = colors.foreground.withValues(alpha: .3),
      );
    }
    if (lastPrice != null) {
      final p = Paint()
        ..color = colors.foreground.withValues(alpha: .45)
        ..strokeWidth = 1;
      final yy = y(lastPrice!);
      for (var x = 0.0; x < plotW; x += 7) {
        canvas.drawLine(Offset(x, yy), Offset(math.min(x + 3, plotW), yy), p);
      }
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.candles != candles ||
      old.width != width ||
      old.height != height ||
      old.min != min ||
      old.range != range ||
      old.colors != colors ||
      old.lastPrice != lastPrice ||
      old.pointerY != pointerY ||
      old.activeIndex != activeIndex;
}
