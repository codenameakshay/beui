/// Curved, animated conversion funnel for ordered stages.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '_shared.dart';

/// Funnel orientation.
enum BeuiFunnelDirection {
  /// Stages flow top to bottom.
  vertical,

  /// Stages flow left to right.
  horizontal,
}

/// One funnel stage.
@immutable
class BeuiFunnelStage {
  /// Creates a funnel stage.
  const BeuiFunnelStage({
    required this.id,
    required this.label,
    required this.value,
    this.color,
  });

  /// Stable identity.
  final String id;

  /// Display label.
  final String label;

  /// Finite, nonnegative count.
  final num value;

  /// Optional hex or theme-token color.
  final String? color;
}

@immutable
class _FunnelRow {
  const _FunnelRow(
    this.stage,
    this.proportion,
    this.conversion,
    this.stepConversion,
    this.change,
  );
  final BeuiFunnelStage stage;
  final double proportion;
  final double? conversion;
  final double? stepConversion;
  final num? change;
}

/// Curved conversion funnel, with stage inspection and summary.
class BeuiFunnelChart extends StatelessWidget {
  /// Creates a funnel chart.
  const BeuiFunnelChart({
    required this.stages,
    super.key,
    this.direction = BeuiFunnelDirection.vertical,
    this.unit = 'people',
    this.label = 'Conversion funnel',
    this.formatValue,
    this.child,
  });

  /// Ordered stages.
  final List<BeuiFunnelStage> stages;

  /// Funnel flow direction.
  final BeuiFunnelDirection direction;

  /// Count unit.
  final String unit;

  /// Accessible label.
  final String label;

  /// Count formatter.
  final String Function(num value)? formatValue;

  /// Custom composition. Defaults to plot and summary.
  final Widget? child;

  List<_FunnelRow> get _rows {
    final ids = <String>{};
    final valid = stages
        .where(
          (stage) =>
              ids.add(stage.id) && stage.value.isFinite && stage.value >= 0,
        )
        .toList();
    final first = valid.firstOrNull?.value ?? 0;
    final maximum = valid.fold<num>(
      0,
      (max, stage) => math.max(max, stage.value),
    );
    return [
      for (var i = 0; i < valid.length; i++)
        _FunnelRow(
          valid[i],
          maximum > 0 ? valid[i].value / maximum : 0,
          first > 0 ? valid[i].value / first * 100 : null,
          i > 0 && valid[i - 1].value > 0
              ? valid[i].value / valid[i - 1].value * 100
              : null,
          i > 0 ? valid[i].value - valid[i - 1].value : null,
        ),
    ];
  }

  String format(num value) =>
      formatValue?.call(value) ??
      (value == value.roundToDouble()
          ? beuiChartFormatNumber(value)
          : beuiChartFormatNumber(value, maximumFractionDigits: 2));

  @override
  Widget build(BuildContext context) => _FunnelScope(
    chart: this,
    child: BeuiChartFrame(
      label: label,
      child:
          child ??
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeuiFunnelPlot(),
              SizedBox(height: 16),
              BeuiFunnelSummary(),
            ],
          ),
    ),
  );
}

class _FunnelScope extends InheritedWidget {
  const _FunnelScope({required this.chart, required super.child});
  final BeuiFunnelChart chart;

  static BeuiFunnelChart of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FunnelScope>();
    assert(scope != null, 'Funnel parts must be inside BeuiFunnelChart.');
    return scope!.chart;
  }

  @override
  bool updateShouldNotify(_FunnelScope old) => old.chart != chart;
}

/// Curved funnel stages rendered as accessible buttons.
class BeuiFunnelPlot extends StatelessWidget {
  /// Creates the plot.
  const BeuiFunnelPlot({super.key, this.height = 280});

  /// Plot height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final chart = _FunnelScope.of(context);
    final rows = chart._rows;
    final colors = BeuiColors.resolve(context);
    if (rows.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('No funnel data')),
      );
    }
    final isHorizontal = chart.direction == BeuiFunnelDirection.horizontal;
    final format = chart.format;
    final palette = [
      const Color(0xFF8B5CF6),
      const Color(0xFF7774EF),
      const Color(0xFF548EE4),
      const Color(0xFF2CA6BC),
      const Color(0xFF14B8A6),
    ];
    return SizedBox(
      height: isHorizontal ? 140 : height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final stageHeight = isHorizontal ? 112.0 : height / rows.length;
          final stageWidth = isHorizontal ? width / rows.length : width;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FunnelPainter(
                    rows: rows,
                    horizontal: isHorizontal,
                    colors: colors,
                    palette: palette,
                    reduce: MediaQuery.disableAnimationsOf(context),
                  ),
                ),
              ),
              for (var i = 0; i < rows.length; i++)
                Positioned(
                  left: isHorizontal ? stageWidth * i : 0,
                  top: isHorizontal ? 0 : stageHeight * i,
                  width: stageWidth,
                  height: stageHeight,
                  child: BeuiChartTooltip(
                    content: _funnelTooltip(rows, i, chart, palette, colors),
                    child: Semantics(
                      key: ValueKey(
                        'funnel-stage-${rows[i].stage.id}-semantics',
                      ),
                      button: true,
                      label:
                          '${rows[i].stage.label}: ${format(rows[i].stage.value)} ${chart.unit}, ${_percent(rows[i].conversion)} of starting total',
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: colors.foreground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              rows[i].stage.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              format(rows[i].stage.value),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Widget _funnelTooltip(
  List<_FunnelRow> rows,
  int index,
  BeuiFunnelChart chart,
  List<Color> palette,
  BeuiColors colors,
) {
  final row = rows[index];
  return BeuiChartTooltipCard(
    title: row.stage.label,
    swatch: row.stage.color == null
        ? palette[index % palette.length]
        : beuiChartColor(row.stage.color, colors),
    lines: [
      '${chart.format(row.stage.value)} ${chart.unit}',
      if (index > 0) '${_percent(row.stepConversion)} from previous stage',
      if (row.change != null)
        '${chart.format(row.change!.abs())} ${row.change! >= 0 ? 'gained' : 'dropped'}',
      '${_percent(row.conversion)} of starting total',
    ],
  );
}

String _percent(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)}%';

class _FunnelPainter extends CustomPainter {
  _FunnelPainter({
    required this.rows,
    required this.horizontal,
    required this.colors,
    required this.palette,
    required this.reduce,
  });
  final List<_FunnelRow> rows;
  final bool horizontal;
  final BeuiColors colors;
  final List<Color> palette;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    final max = rows.map((row) => row.proportion).fold<double>(0, math.max);
    final unit = horizontal ? size.height : size.width;
    final centers = <Offset>[];
    final widths = <double>[];
    for (var i = 0; i <= rows.length; i++) {
      final proportion = i == 0
          ? rows.first.proportion
          : i == rows.length
          ? rows.last.proportion
          : (rows[i - 1].proportion + rows[i].proportion) / 2;
      widths.add(unit * (max == 0 ? 0 : proportion / max) * 0.92);
      centers.add(
        horizontal
            ? Offset(size.width * i / rows.length, size.height / 2)
            : Offset(size.width / 2, size.height * i / rows.length),
      );
    }
    for (var i = 0; i < rows.length; i++) {
      final a = centers[i], b = centers[i + 1];
      final w0 = widths[i], w1 = widths[i + 1];
      final gap = horizontal ? b.dx - a.dx : b.dy - a.dy;
      final path = Path();
      if (horizontal) {
        path
          ..moveTo(a.dx, a.dy - w0 / 2)
          ..cubicTo(
            a.dx + gap / 3,
            a.dy - w0 / 2,
            b.dx - gap / 3,
            b.dy - w1 / 2,
            b.dx,
            b.dy - w1 / 2,
          )
          ..lineTo(b.dx, b.dy + w1 / 2)
          ..cubicTo(
            b.dx - gap / 3,
            b.dy + w1 / 2,
            a.dx + gap / 3,
            a.dy + w0 / 2,
            a.dx,
            a.dy + w0 / 2,
          )
          ..close();
      } else {
        path
          ..moveTo(a.dx - w0 / 2, a.dy)
          ..cubicTo(
            a.dx - w0 / 2,
            a.dy + gap / 3,
            b.dx - w1 / 2,
            b.dy - gap / 3,
            b.dx - w1 / 2,
            b.dy,
          )
          ..lineTo(b.dx + w1 / 2, b.dy)
          ..cubicTo(
            b.dx + w1 / 2,
            b.dy - gap / 3,
            a.dx + w0 / 2,
            a.dy + gap / 3,
            a.dx + w0 / 2,
            a.dy,
          )
          ..close();
      }
      final stage = rows[i].stage;
      final color = stage.color == null
          ? palette[i % palette.length]
          : beuiChartColor(stage.color, colors);
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_FunnelPainter old) => true;
}

/// Overall conversion summary for the funnel.
class BeuiFunnelSummary extends StatelessWidget {
  /// Creates the summary.
  const BeuiFunnelSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final chart = _FunnelScope.of(context);
    final rows = chart._rows;
    final colors = BeuiColors.resolve(context);
    if (rows.isEmpty) return const SizedBox.shrink();
    final first = rows.first.stage.value;
    final last = rows.last.stage.value;
    final conversion = first > 0 ? last / first * 100 : null;
    return Semantics(
      label: 'Overall conversion ${_percent(conversion)}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${chart.format(first)} ${chart.unit} → ${chart.format(last)} ${chart.unit}',
          ),
          Text(
            _percent(conversion),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
