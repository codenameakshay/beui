/// Liquidity depth across discrete price bands and time snapshots.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
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
    final activeColumn = activeCol < 0 ? null : columns[activeCol];
    final activePrice = activeRow < 0 ? null : prices[activeRow];
    final activeSize = activeColumn == null
        ? null
        : activeColumn.levels[activePrice];
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => handleInspectorKey(event)
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
                                        case final p?)
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
                                    onHover: (hovering) => setActiveId(
                                      hovering
                                          ? _ids[row * columns.length + col]
                                          : null,
                                    ),
                                    onFocusChange: (focused) => setActiveId(
                                      focused
                                          ? _ids[row * columns.length + col]
                                          : null,
                                    ),
                                    onTap: () => setActiveId(
                                      _ids[row * columns.length + col],
                                    ),
                                    child: SizedBox(
                                      height: 18,
                                      child: BeuiChartFade(
                                        opacity:
                                            columns[col].levels.containsKey(
                                              prices[row],
                                            )
                                            ? 1
                                            : 0,
                                        child: DecoratedBox(
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
                          width: 54,
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
                  padding: const EdgeInsets.only(right: 54),
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LiquidityTracePainter(
                        columns: columns,
                        prices: prices,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final c in columns)
                Expanded(
                  child: Text(
                    c.snapshot.label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              const SizedBox(width: 54),
            ],
          ),
          if (activeColumn != null && activePrice != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${activeColumn.snapshot.label} · ${scope.formatPrice(activePrice)} · '
                  '${activeSize == null ? 'No data' : '${scope.formatSize(activeSize)} ${scope.unit}'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                ),
              ),
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
  const _LiquidityTracePainter({
    required this.columns,
    required this.prices,
    required this.color,
  });
  final List<_LiquidityColumn> columns;
  final List<double> prices;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (columns.length < 2 || prices.length < 2) return;
    final path = Path();
    var connected = false;
    for (var i = 0; i < columns.length; i++) {
      final price = columns[i].snapshot.price;
      final row = price == null ? -1 : _pricePosition(price, prices);
      if (row < 0) {
        connected = false;
        continue;
      }
      final point = Offset(
        size.width * (i + .5) / columns.length,
        size.height * (row + .5) / prices.length,
      );
      if (!connected) {
        path.moveTo(point.dx, point.dy);
        connected = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .9)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_LiquidityTracePainter old) =>
      columns != old.columns || prices != old.prices || color != old.color;
}

int _pricePosition(double price, List<double> prices) {
  if (!price.isFinite ||
      prices.isEmpty ||
      price > prices.first ||
      price < prices.last) {
    return -1;
  }
  for (var i = 0; i < prices.length - 1; i++) {
    if (price <= prices[i] && price >= prices[i + 1]) return i;
  }
  return prices.length - 1;
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
