/// Curved, animated conversion funnel for ordered stages.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '../motion/tooltip.dart';
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
              stage.value.isFinite && stage.value >= 0 && ids.add(stage.id),
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

  /// Formats a stage count.
  String format(num value) =>
      formatValue?.call(value) ?? _formatFunnelCount(value);

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
              SizedBox(height: 24),
              BeuiFunnelSummary(),
            ],
          ),
    ),
  );
}

String _formatFunnelCount(num value) {
  final parts = value.abs().toString().toLowerCase().split('e');
  final decimal = parts.first.split('.');
  final fraction = decimal.length > 1 ? decimal.last : '';
  final exponent = parts.length > 1 ? int.parse(parts.last) : 0;
  var rounded = BigInt.parse('${decimal.first}$fraction');
  final shift = exponent - fraction.length + 2;
  if (shift >= 0) {
    rounded *= BigInt.from(10).pow(shift);
  } else {
    final divisor = BigInt.from(10).pow(-shift);
    final remainder = rounded.remainder(divisor);
    rounded ~/= divisor;
    if (remainder * BigInt.two >= divisor) rounded += BigInt.one;
  }
  final digits = rounded.toString().padLeft(3, '0');
  final whole = digits
      .substring(0, digits.length - 2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final cents = digits
      .substring(digits.length - 2)
      .replaceFirst(RegExp(r'0+$'), '');
  return '${value.isNegative ? '-' : ''}$whole${cents.isEmpty ? '' : '.$cents'}';
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

const _palette = [
  Color(0xFF8B5CF6),
  Color(0xFF7774EF),
  Color(0xFF548EE4),
  Color(0xFF2CA6BC),
  Color(0xFF14B8A6),
];
Color _stageColor(_FunnelRow row, int index, BeuiColors colors) =>
    row.stage.color == null
    ? _palette[index % _palette.length]
    : beuiChartColor(row.stage.color, colors);

/// Curved funnel stages rendered as accessible buttons.
class BeuiFunnelPlot extends StatelessWidget {
  /// Creates the plot.
  const BeuiFunnelPlot({super.key, this.height});

  /// Optional vertical plot height. Defaults to at least 72px per stage.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final chart = _FunnelScope.of(context);
    final rows = chart._rows;
    final colors = BeuiColors.resolve(context);
    if (rows.isEmpty) {
      return SizedBox(
        height: 148,
        child: Center(
          child: Text(
            'No funnel data',
            style: TextStyle(fontSize: 14, color: colors.mutedForeground),
          ),
        ),
      );
    }
    final horizontal = chart.direction == BeuiFunnelDirection.horizontal;
    final plotHeight = horizontal
        ? 300.0
        : height ?? math.max(320.0, rows.length * 72.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.max(
              constraints.maxWidth,
              horizontal ? rows.length * 110.0 : 240.0,
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: plotHeight,
                child: Stack(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      Positioned.fill(
                        key: ValueKey('funnel-shape-${rows[i].stage.id}'),
                        child: _FunnelShape(
                          points: _funnelPoints(
                            rows.map((row) => row.proportion).toList(),
                            i,
                            horizontal,
                          ),
                          color: _stageColor(rows[i], i, colors),
                        ),
                      ),
                    for (var i = 0; i < rows.length; i++)
                      Positioned(
                        key: ValueKey('funnel-button-${rows[i].stage.id}'),
                        left: horizontal ? width * i / rows.length : 0,
                        top: horizontal ? 0 : plotHeight * i / rows.length,
                        width: horizontal ? width / rows.length : width,
                        height: horizontal
                            ? plotHeight
                            : plotHeight / rows.length,
                        child: BeuiTooltip(
                          content: _funnelTooltip(rows, i, chart, colors),
                          child: Semantics(
                            key: ValueKey(
                              'funnel-stage-${rows[i].stage.id}-semantics',
                            ),
                            button: true,
                            label:
                                '${rows[i].stage.label}: ${chart.format(rows[i].stage.value)} ${chart.unit}, ${_percent(rows[i].conversion)} of starting total',
                            child: _FunnelStageButton(
                              value: chart.format(rows[i].stage.value),
                              colors: colors,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            for (var i = 0; i < rows.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiChartSwatch(
                    color: _stageColor(rows[i], i, colors),
                    size: 8,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rows[i].stage.label,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _percent(rows[i].conversion),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      height: 1.5,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _FunnelStageButton extends StatefulWidget {
  const _FunnelStageButton({required this.value, required this.colors});
  final String value;
  final BeuiColors colors;

  @override
  State<_FunnelStageButton> createState() => _FunnelStageButtonState();
}

class _FunnelStageButtonState extends State<_FunnelStageButton> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Listener(
      onPointerDown: (_) => _focus.requestFocus(),
      child: TextButton(
        focusNode: _focus,
        onPressed: () {},
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: const WidgetStatePropertyAll(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? colors.foreground.withValues(alpha: .05)
                : Colors.transparent,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.focused) &&
                    FocusManager.instance.highlightMode ==
                        FocusHighlightMode.traditional
                ? BorderSide(color: colors.ring, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _funnelTooltip(
  List<_FunnelRow> rows,
  int index,
  BeuiFunnelChart chart,
  BeuiColors colors,
) {
  final row = rows[index];
  return DefaultTextStyle(
    style: TextStyle(fontSize: 12, height: 16 / 12, color: colors.foreground),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.stage.label, style: TextStyle(color: colors.mutedForeground)),
        const SizedBox(height: 6),
        BeuiChartTicker(
          value: row.stage.value,
          duration: const Duration(milliseconds: 350),
          format: (_) => '${chart.format(row.stage.value)} ${chart.unit}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: colors.foreground,
          ),
        ),
        if (index > 0) ...[
          const SizedBox(height: 6),
          Text('${_percent(row.stepConversion)} from previous stage'),
          const SizedBox(height: 6),
          Text(
            '${chart.format(row.change!.abs())} ${row.change! > 0 ? 'gained' : 'dropped'}',
            style: TextStyle(color: colors.mutedForeground),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          '${_percent(row.conversion)} of starting total',
          style: TextStyle(color: colors.mutedForeground),
        ),
      ],
    ),
  );
}

String _percent(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)}%';

List<double> _funnelPoints(
  List<double> proportions,
  int index,
  bool horizontal,
) {
  final value = proportions[index];
  final top = index == 0 ? value : (proportions[index - 1] + value) / 2;
  final bottom = index == proportions.length - 1
      ? value
      : (value + proportions[index + 1]) / 2;
  final start = index / proportions.length,
      end = (index + 1) / proportions.length;
  final middle = (start + end) / 2, quarter = (end - start) / 4;
  double left(double width) => .5 - width * .46;
  double right(double width) => .5 + width * .46;
  List<double> point(double cross, double along) =>
      horizontal ? [along, cross] : [cross, along];
  return [
    ...point(left(top), start),
    ...point(right(top), start),
    ...point(right(top), start + quarter),
    ...point(right(value), middle - quarter),
    ...point(right(value), middle),
    ...point(right(value), middle + quarter),
    ...point(right(bottom), end - quarter),
    ...point(right(bottom), end),
    ...point(left(bottom), end),
    ...point(left(bottom), end - quarter),
    ...point(left(value), middle + quarter),
    ...point(left(value), middle),
    ...point(left(value), middle - quarter),
    ...point(left(top), start + quarter),
    ...point(left(top), start),
  ];
}

class _FunnelShape extends StatelessWidget {
  const _FunnelShape({required this.points, required this.color});
  final List<double> points;
  final Color color;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<List<double>>(
    tween: _FunnelPointsTween(begin: points, end: points),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280),
    curve: beuiEaseOut,
    builder: (context, value, _) => CustomPaint(
      painter: _FunnelPainter(points: value, color: color),
    ),
  );
}

class _FunnelPointsTween extends Tween<List<double>> {
  _FunnelPointsTween({required super.begin, required super.end});
  @override
  List<double> lerp(double t) =>
      List.generate(end!.length, (i) => begin![i] + (end![i] - begin![i]) * t);
}

class _FunnelPainter extends CustomPainter {
  _FunnelPainter({required this.points, required this.color});
  final List<double> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    double x(int i) => points[i * 2] * size.width;
    double y(int i) => points[i * 2 + 1] * size.height;
    final path = Path()
      ..moveTo(x(0), y(0))
      ..lineTo(x(1), y(1))
      ..cubicTo(x(2), y(2), x(3), y(3), x(4), y(4))
      ..cubicTo(x(5), y(5), x(6), y(6), x(7), y(7))
      ..lineTo(x(8), y(8))
      ..cubicTo(x(9), y(9), x(10), y(10), x(11), y(11))
      ..cubicTo(x(12), y(12), x(13), y(13), x(14), y(14))
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FunnelPainter old) =>
      old.points != points || old.color != color;
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
    return Semantics(
      label: 'Overall conversion ${_percent(rows.last.conversion)}',
      child: Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            color: colors.mutedForeground,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                '${chart.format(rows.first.stage.value)} → ${chart.format(rows.last.stage.value)} ${chart.unit}',
              ),
              Wrap(
                spacing: 8,
                children: [
                  const Text('Overall conversion'),
                  Text(
                    _percent(rows.last.conversion),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
