/// Liquidity depth across discrete price bands and time snapshots.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart';

/// One time-ordered order-book observation.
@immutable
class BeuiLiquiditySnapshot {
  /// Creates a snapshot with a stable identity and discrete price levels.
  const BeuiLiquiditySnapshot({
    required this.id,
    required this.label,
    required this.levels,
    this.price,
  });

  /// Stable identity retained across streaming updates.
  final String id;

  /// Short time label.
  final String label;

  /// Discrete price/size observations.
  final List<BeuiLiquidityLevel> levels;

  /// Optional market price for the overlaid trace.
  final double? price;
}

/// Liquidity at one discrete price band.
@immutable
class BeuiLiquidityLevel {
  /// Creates a price and size pair.
  const BeuiLiquidityLevel({required this.price, required this.size});

  /// Price of the band.
  final double price;

  /// Resting size; zero is distinct from missing data.
  final double size;
}

/// Animated liquidity bands across price and time.
class BeuiLiquidityHeatmap extends StatelessWidget {
  /// Creates a heatmap, including its plot and color-scale legend by default.
  const BeuiLiquidityHeatmap({
    required this.snapshots,
    super.key,
    this.maxSize,
    this.unit = 'units',
    this.label = 'Liquidity heatmap',
    this.formatPrice,
    this.formatSize,
    this.child,
  });

  /// Time-ordered snapshots with consistent price buckets and stable IDs.
  final List<BeuiLiquiditySnapshot> snapshots;

  /// Fixed intensity ceiling for comparable streaming colors.
  final double? maxSize;

  /// Unit label for sizes.
  final String unit;

  /// Accessible chart label.
  final String label;

  /// Optional price formatter.
  final String Function(double value)? formatPrice;

  /// Optional size formatter.
  final String Function(double value)? formatSize;

  /// Custom chart composition; defaults to plot and legend.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return _LiquidityScope(
      snapshots: snapshots,
      ceiling: maxSize ?? 0,
      unit: unit,
      formatPrice:
          formatPrice ??
          (v) => beuiChartFormatNumber(v, maximumFractionDigits: 2),
      formatSize: formatSize ?? (v) => beuiChartFormatNumber(v, compact: true),
      child: BeuiChartFrame(
        label: label,
        child:
            child ??
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BeuiLiquidityPlot(),
                SizedBox(height: 12),
                BeuiLiquidityLegend(),
              ],
            ),
      ),
    );
  }
}

class _LiquidityScope extends InheritedWidget {
  const _LiquidityScope({
    required this.snapshots,
    required this.ceiling,
    required this.unit,
    required this.formatPrice,
    required this.formatSize,
    required super.child,
  });

  final List<BeuiLiquiditySnapshot> snapshots;
  final double ceiling;
  final String unit;
  final String Function(double) formatPrice;
  final String Function(double) formatSize;

  static _LiquidityScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LiquidityScope>()!;

  @override
  bool updateShouldNotify(_LiquidityScope old) =>
      snapshots != old.snapshots || ceiling != old.ceiling || unit != old.unit;
}

/// Accessible grid of price bands with an optional market-price trace.
class BeuiLiquidityPlot extends StatefulWidget {
  /// Creates the interactive plot.
  const BeuiLiquidityPlot({super.key});

  @override
  State<BeuiLiquidityPlot> createState() => _BeuiLiquidityPlotState();
}

class _BeuiLiquidityPlotState extends State<BeuiLiquidityPlot>
    with BeuiChartInspectorKeys {
  String? _active;
  String? _cursor;
  final _focus = <String, FocusNode>{};

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  bool _handleGridKey(KeyEvent event, int columns) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setActiveId(null);
      return true;
    }
    final index = math.max(0, _ids.indexOf(_cursor ?? _active ?? ''));
    final column = index % columns;
    final offset = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowDown => columns,
      LogicalKeyboardKey.arrowUp => -columns,
      LogicalKeyboardKey.home => -column,
      LogicalKeyboardKey.end => columns - 1 - column,
      _ => null,
    };
    if (offset == null) return false;
    final id = _ids[(index + offset).clamp(0, _ids.length - 1)];
    _focus[id]?.requestFocus();
    setState(() => _cursor = id);
    setActiveId(id);
    return true;
  }

  @override
  String? get activeId => _active;
  late List<String> _ids;
  @override
  List<String> get inspectableIds => _ids;
  @override
  void setActiveId(String? id) => setState(() => _active = id);

  @override
  Widget build(BuildContext context) {
    final scope = _LiquidityScope.of(context);
    final columns = <_LiquidityColumn>[];
    final seen = <String>{};
    for (final snapshot in scope.snapshots) {
      if (!seen.add(snapshot.id)) continue;
      final levels = <double, double>{};
      for (final level in snapshot.levels) {
        if (!level.price.isFinite ||
            level.price <= 0 ||
            !level.size.isFinite ||
            level.size < 0) {
          continue;
        }
        levels.update(
          level.price,
          (value) => value + level.size,
          ifAbsent: () => level.size,
        );
      }
      columns.add(_LiquidityColumn(snapshot, levels));
    }
    final prices = columns.expand((c) => c.levels.keys).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    _ids = [
      for (final p in prices)
        for (final c in columns) '${c.snapshot.id}:$p',
    ];
    for (final id in _focus.keys.where((id) => !_ids.contains(id)).toList()) {
      _focus.remove(id)!.dispose();
    }
    for (final id in _ids) {
      _focus.putIfAbsent(id, FocusNode.new);
    }
    if (!_ids.contains(_cursor)) _cursor = _ids.firstOrNull;
    for (final entry in _focus.entries) {
      entry.value.skipTraversal = entry.key != _cursor;
    }
    if (columns.isEmpty || prices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('No liquidity data')),
      );
    }
    final maximum = scope.ceiling > 0 && scope.ceiling.isFinite
        ? scope.ceiling
        : columns
              .expand((c) => c.levels.values)
              .fold<double>(
                0,
                (current, value) => math.max(current, value).toDouble(),
              );
    final colors = BeuiColors.resolve(context);
    final palette = <Color>[
      const Color(0xFF17233B),
      const Color(0xFF254F80),
      const Color(0xFF217C90),
      const Color(0xFF27AF98),
      const Color(0xFF97D56B),
      const Color(0xFFF4DF76),
    ];
    final index = _active == null ? -1 : _ids.indexOf(_active!);
    final activeRow = index < 0 ? -1 : index ~/ columns.length;
    final activeCol = index < 0 ? -1 : index % columns.length;
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _handleGridKey(event, columns.length)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Column(
                children: [
                  for (var row = 0; row < prices.length; row++)
                    Row(
                      children: [
                        for (var col = 0; col < columns.length; col++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: BeuiChartTooltip(
                                open: row == activeRow && col == activeCol,
                                onOpenChange: (open) {
                                  if (!open &&
                                      row == activeRow &&
                                      col == activeCol &&
                                      _active ==
                                          _ids[row * columns.length + col]) {
                                    setActiveId(null);
                                  }
                                },
                                content: BeuiChartTooltipCard(
                                  title:
                                      '${columns[col].snapshot.label} · ${scope.formatPrice(prices[row])}',
                                  titleWidget: Text(
                                    '${columns[col].snapshot.label} · ${scope.formatPrice(prices[row])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.mutedForeground,
                                    ),
                                  ),
                                  details: [
                                    if (columns[col].levels[prices[row]]
                                        case final size?)
                                      BeuiChartTicker(
                                        value: size,
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        format: (value) =>
                                            '${scope.formatSize(value.toDouble())} ${scope.unit}',
                                      )
                                    else
                                      const Text('No data'),
                                    if (columns[col].snapshot.price
                                        case final p? when p.isFinite)
                                      Text('Market ${scope.formatPrice(p)}'),
                                  ],
                                ),
                                child: Semantics(
                                  button: true,
                                  selected:
                                      row == activeRow && col == activeCol,
                                  label:
                                      '${columns[col].snapshot.label}, ${scope.formatPrice(prices[row])}: '
                                      '${columns[col].levels[prices[row]] == null ? 'No data' : '${scope.formatSize(columns[col].levels[prices[row]]!)} ${scope.unit}'}',
                                  child: InkWell(
                                    focusNode:
                                        _focus[_ids[row * columns.length +
                                            col]],
                                    onHover: (hovering) => setActiveId(
                                      hovering
                                          ? _ids[row * columns.length + col]
                                          : null,
                                    ),
                                    onFocusChange: (focused) {
                                      final id =
                                          _ids[row * columns.length + col];
                                      if (focused) {
                                        _cursor = id;
                                      }
                                      if (focused || _active == id) {
                                        setActiveId(focused ? id : null);
                                      }
                                    },
                                    onTap: () {
                                      final id =
                                          _ids[row * columns.length + col];
                                      _focus[id]!.requestFocus();
                                      setActiveId(id);
                                    },
                                    child: SizedBox(
                                      height: 24,
                                      child: BeuiChartFade(
                                        opacity:
                                            columns[col].levels.containsKey(
                                              prices[row],
                                            )
                                            ? 1
                                            : 0,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 280,
                                          ),
                                          curve: beuiEaseOut,
                                          decoration: BoxDecoration(
                                            color:
                                                palette[(maximum <= 0
                                                        ? 0
                                                        : ((columns[col].levels[prices[row]] ??
                                                                      0) /
                                                                  maximum *
                                                                  palette
                                                                      .length)
                                                              .floor())
                                                    .clamp(
                                                      0,
                                                      palette.length - 1,
                                                    )],
                                            border:
                                                row == activeRow &&
                                                    col == activeCol
                                                ? Border.all(
                                                    color: colors.foreground,
                                                    width: 1.5,
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: 72,
                          child: Text(
                            scope.formatPrice(prices[row]),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 9,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(right: 72),
                  child: IgnorePointer(
                    child: _LiquidityTrace(columns: columns, prices: prices),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < columns.length; i++)
                if (i % math.max(1, (columns.length / 5).ceil()) == 0 ||
                    i == columns.length - 1)
                  Text(
                    columns[i].snapshot.label,
                    style: TextStyle(
                      fontSize: 9,
                      color: colors.mutedForeground,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiquidityColumn {
  const _LiquidityColumn(this.snapshot, this.levels);
  final BeuiLiquiditySnapshot snapshot;
  final Map<double, double> levels;
}

class _LiquidityTracePainter extends CustomPainter {
  const _LiquidityTracePainter({required this.points});
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    Offset? previous;
    for (final normalized in points) {
      if (normalized == null) {
        previous = null;
        continue;
      }
      final point = Offset(
        normalized.dx * size.width,
        normalized.dy * size.height,
      );
      if (previous == null) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      previous = point;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: .35)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_LiquidityTracePainter old) => points != old.points;
}

class _LiquidityTrace extends StatefulWidget {
  const _LiquidityTrace({required this.columns, required this.prices});
  final List<_LiquidityColumn> columns;
  final List<double> prices;
  @override
  State<_LiquidityTrace> createState() => _LiquidityTraceState();
}

class _LiquidityTraceState extends State<_LiquidityTrace>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late List<Offset?> _from = _target;
  late List<Offset?> _to = _target;
  List<Offset?> get _target => [
    for (var i = 0; i < widget.columns.length; i++)
      if (widget.columns[i].snapshot.price case final price?
          when _priceInDomain(price, widget.prices))
        Offset(
          (i + .5) / widget.columns.length,
          _yForPrice(price, const Size(1, 1), widget.prices),
        )
      else
        null,
  ];
  List<Offset?> get _current {
    final t = beuiEaseOut.transform(_controller.value);
    return [
      for (var i = 0; i < _to.length; i++)
        _to[i] == null ? null : Offset.lerp(_from[i], _to[i], t),
    ];
  }

  @override
  void didUpdateWidget(covariant _LiquidityTrace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _target;
    final sameTopology =
        oldWidget.columns.length == widget.columns.length &&
        List.generate(
          widget.columns.length,
          (i) =>
              oldWidget.columns[i].snapshot.id ==
                  widget.columns[i].snapshot.id &&
              (_to[i] == null) == (next[i] == null),
        ).every((same) => same);
    if (sameTopology &&
        List.generate(
          next.length,
          (i) => next[i] == _to[i],
        ).every((same) => same)) {
      return;
    }
    _from = sameTopology ? _current : next;
    _to = next;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => CustomPaint(
      painter: _LiquidityTracePainter(
        points: MediaQuery.disableAnimationsOf(context) ? _to : _current,
      ),
    ),
  );
}

bool _priceInDomain(double price, List<double> prices) =>
    price.isFinite &&
    prices.isNotEmpty &&
    price <= prices.first &&
    price >= prices.last;

double _yForPrice(double price, Size size, List<double> prices) {
  for (var row = 0; row < prices.length - 1; row++) {
    final upper = prices[row];
    final lower = prices[row + 1];
    if (price >= lower) {
      final fraction = (upper - price) / (upper - lower);
      return size.height * (row + .5 + fraction) / prices.length;
    }
  }
  return size.height * (prices.length - .5) / prices.length;
}

/// Color scale for resting liquidity.
class BeuiLiquidityLegend extends StatelessWidget {
  /// Creates the color-scale legend.
  const BeuiLiquidityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = _LiquidityScope.of(context);
    final colors = BeuiColors.resolve(context);
    const palette = [
      Color(0xFF17233B),
      Color(0xFF254F80),
      Color(0xFF217C90),
      Color(0xFF27AF98),
      Color(0xFF97D56B),
      Color(0xFFF4DF76),
    ];
    final ceiling = scope.ceiling > 0 ? scope.ceiling : 0.0;
    return Row(
      children: [
        Text(
          'Resting liquidity · ${scope.unit}',
          style: TextStyle(fontSize: 10, color: colors.mutedForeground),
        ),
        const Spacer(),
        const Text('0', style: TextStyle(fontSize: 10)),
        const SizedBox(width: 6),
        for (final color in palette)
          Container(width: 16, height: 8, color: color),
        const SizedBox(width: 6),
        Text(
          '${scope.formatSize(ceiling)}+',
          style: TextStyle(fontSize: 10, color: colors.mutedForeground),
        ),
      ],
    );
  }
}
