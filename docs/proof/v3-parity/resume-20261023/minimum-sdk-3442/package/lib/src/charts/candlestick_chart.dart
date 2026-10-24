/// OHLC candles with volume, a last-price line, and a crosshair readout.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
      (v) => beuiChartFormatNumber(
        v,
        maximumFractionDigits: 2,
      ).replaceFirst(RegExp(r'\.?0+$'), '');
  String Function(double) get volume => widget.formatVolume ?? _candleVolume;

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BeuiCandlestickLegend(),
              if (widget.candles.isNotEmpty) const SizedBox(height: 12),
              const BeuiCandlestickPlot(),
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
    final change = candle.open == 0
        ? 0.0
        : (candle.close - candle.open) / candle.open * 100;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = change >= 0
        ? (dark ? const Color(0xff00d492) : const Color(0xff009966))
        : (dark ? const Color(0xffff637e) : const Color(0xffec003f));
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
            ('Vol', candle.volume),
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.$1, style: TextStyle(color: colors.mutedForeground)),
                const SizedBox(width: 4),
                Text(
                  entry.$1 == 'Vol'
                      ? state.volume(entry.$2)
                      : state.price(entry.$2),
                  key: ValueKey('candle-legend-${entry.$1}'),
                  style: TextStyle(
                    color: entry.$1 == 'Vol' ? colors.foreground : tone,
                  ),
                ),
              ],
            ),
          Text(
            '${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(2)}%',
            style: TextStyle(color: tone, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _candleVolume(double value) {
  const suffixes = ['', 'K', 'M', 'B', 'T'];
  var scaled = value;
  var unit = 0;
  while (scaled.abs() >= 1000 && unit < suffixes.length - 1) {
    scaled /= 1000;
    unit++;
  }
  if ((scaled.abs() * 10).round() >= 10000 && unit < suffixes.length - 1) {
    scaled /= 1000;
    unit++;
  }
  return '${beuiChartFormatNumber(scaled, maximumFractionDigits: 1).replaceFirst(RegExp(r'\.0$'), '')}${suffixes[unit]}';
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
  bool _showFocus = false;
  bool _pointerFocus = false;

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
          String describe(BeuiCandle candle) =>
              '${candle.time}: open ${state.price(candle.open)}, high ${state.price(candle.high)}, low ${state.price(candle.low)}, close ${state.price(candle.close)}';
          return Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              final ids = candles.map((c) => c.id).toList();
              if (ids.isEmpty) return KeyEventResult.ignored;
              final key = event.logicalKey;
              _pointerFocus = false;
              setState(() => _showFocus = true);
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
            child: FocusableActionDetector(
              focusNode: _focus,
              includeFocusSemantics: false,
              onShowFocusHighlight: (visible) {
                setState(() => _showFocus = visible && !_pointerFocus);
              },
              onFocusChange: (focused) {
                setState(() => _showFocus = focused && !_pointerFocus);
                if (!focused) {
                  state.setActiveId(null);
                  setState(() => _pointerY = null);
                }
              },
              child: DecoratedBox(
                key: const ValueKey('candle-focus-ring'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: _showFocus
                      ? Border.all(
                          color: colors.ring,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        )
                      : null,
                ),
                child: Semantics(
                  slider: true,
                  focusable: true,
                  focused: _focus.hasFocus,
                  onFocus: _focus.requestFocus,
                  increasedValue: candle == null
                      ? null
                      : describe(
                          candles[math.min(index + 1, candles.length - 1)],
                        ),
                  decreasedValue: candle == null
                      ? null
                      : describe(candles[math.max(index - 1, 0)]),
                  onIncrease: candles.isEmpty
                      ? null
                      : () => state.setActiveId(
                          candles[math.min(index + 1, candles.length - 1)].id,
                        ),
                  onDecrease: candles.isEmpty
                      ? null
                      : () => state.setActiveId(
                          candles[math.max(index - 1, 0)].id,
                        ),
                  label: state.widget.label,
                  value: candle == null ? null : describe(candle),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.precise,
                    onEnter: (event) {
                      if (event.kind != PointerDeviceKind.touch) {
                        inspect(event.localPosition);
                      }
                    },
                    onHover: (event) {
                      if (event.kind != PointerDeviceKind.touch) {
                        inspect(event.localPosition);
                      }
                    },
                    onExit: (_) {
                      state.setActiveId(null);
                      setState(() => _pointerY = null);
                    },
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _pointerFocus = true;
                        setState(() => _showFocus = false);
                        _focus.requestFocus();
                      },
                      onPointerMove: (event) => inspect(event.localPosition),
                      onPointerUp: (event) {
                        if (event.kind == PointerDeviceKind.touch) {
                          state.setActiveId(null);
                          setState(() => _pointerY = null);
                        }
                      },
                      onPointerCancel: (_) {
                        state.setActiveId(null);
                        setState(() => _pointerY = null);
                      },
                      child: BeuiChartSpring(
                        key: ValueKey(state.widget.lastPrice == null),
                        value: state.widget.lastPrice == null
                            ? 0
                            : y(state.widget.lastPrice!),
                        builder: (context, priceY) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                size: Size(plotWidth, height),
                                painter: _CandlePainter(
                                  candles: candles,
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
                                      : minPrice -
                                            pad +
                                            (1 - priceY / priceHeight) * range,
                                  activeIndex: activeIndex,
                                  pointerY: _pointerY,
                                  colors: colors,
                                ),
                              ),
                              for (var i = 0; i < candles.length; i++)
                                Positioned.fill(
                                  key: ValueKey(candles[i].id),
                                  child: _AnimatedCandle(
                                    candle: candles[i],
                                    index: i,
                                    slot: candles.isEmpty
                                        ? 0
                                        : plotWidth / candles.length,
                                    height: height,
                                    priceHeight: priceHeight,
                                    y: y,
                                    maxVolume: candles.fold<double>(
                                      1,
                                      (m, c) => math.max(m, c.volume),
                                    ),
                                    dimmed:
                                        activeIndex >= 0 && activeIndex != i,
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
                                  top: priceY - 10,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.foreground,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        state.price(state.widget.lastPrice!),
                                        key: const ValueKey(
                                          'candle-last-price',
                                        ),
                                        style: TextStyle(
                                          color: colors.background,
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
                      ),
                    ),
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
    if (activeIndex >= 0) {
      final x = (activeIndex + .5) * slot;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, height),
        Paint()..color = colors.foreground.withValues(alpha: .3),
      );
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

class _AnimatedCandle extends StatelessWidget {
  const _AnimatedCandle({
    required this.candle,
    required this.index,
    required this.slot,
    required this.height,
    required this.priceHeight,
    required this.y,
    required this.maxVolume,
    required this.dimmed,
  });
  final BeuiCandle candle;
  final int index;
  final double slot, height, priceHeight, maxVolume;
  final double Function(double) y;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final x = (index + .5) * slot;
    final width = math.max(1.0, slot * .62);
    final top = y(math.max(candle.open, candle.close));
    final wickTop = y(candle.high);
    final volumeHeight = math.max(.5, candle.volume / maxVolume * height * .18);
    final color = candle.close >= candle.open
        ? const Color(0xFF00BC7D)
        : const Color(0xFFFF2056);
    final shapes = [
      Rect.fromLTWH(x, wickTop, 0, math.max(1, y(candle.low) - wickTop)),
      Rect.fromLTWH(
        x - width / 2,
        top,
        width,
        math.max(1, (y(candle.open) - y(candle.close)).abs()),
      ),
      Rect.fromLTWH(x - width / 2, height - volumeHeight, width, volumeHeight),
    ];
    return IgnorePointer(
      child: _CandleOpacity(
        value: dimmed ? .45 : 1,
        delay: Duration(milliseconds: math.min(index * 12, 600)),
        builder: (context, opacity) => Opacity(
          opacity: opacity.clamp(0, 1),
          child: Stack(
            children: [
              for (var i = 0; i < shapes.length; i++)
                Positioned.fill(
                  child: BeuiChartSpringRect(
                    value: shapes[i],
                    builder: (context, rect) => CustomPaint(
                      painter: _CandleShapePainter(
                        rect: rect,
                        wick: i == 0,
                        color: color.withValues(alpha: i == 2 ? .28 : 1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandleOpacity extends StatefulWidget {
  const _CandleOpacity({
    required this.value,
    required this.delay,
    required this.builder,
  });
  final double value;
  final Duration delay;
  final Widget Function(BuildContext, double) builder;

  @override
  State<_CandleOpacity> createState() => _CandleOpacityState();
}

class _CandleOpacityState extends State<_CandleOpacity> {
  Timer? _timer;
  late double _target;
  late double _initial;
  late double _current;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initial = MediaQuery.disableAnimationsOf(context) ? widget.value : 0;
      _target = _initial;
      _current = _initial;
      _retarget();
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _target = widget.value;
    }
  }

  void _retarget() {
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context) ||
        widget.delay == Duration.zero) {
      _target = widget.value;
    } else {
      _target = _current;
      _timer = Timer(
        widget.delay,
        () => setState(() => _target = widget.value),
      );
    }
  }

  @override
  void didUpdateWidget(_CandleOpacity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.delay != widget.delay) {
      _retarget();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BeuiChartTween(
    from: _initial,
    value: _target,
    duration: const Duration(milliseconds: 300),
    builder: (context, value) {
      _current = value;
      return widget.builder(context, value);
    },
  );
}

class _CandleShapePainter extends CustomPainter {
  const _CandleShapePainter({
    required this.rect,
    required this.wick,
    required this.color,
  });
  final Rect rect;
  final bool wick;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (wick) {
      canvas.drawLine(rect.topLeft, rect.bottomLeft, paint..strokeWidth = 1);
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_CandleShapePainter old) =>
      old.rect != rect || old.color != color;
}
