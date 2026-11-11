/// Compact, source-faithful XY sparkline for inline metrics and stat cards.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/_engine.dart' show MotionBuilder, OffsetMotionConverter;
import '../theme/beui_colors.dart';
import '../tokens/motion.dart' show beuiEaseOut, beuiSpringLayout, motionFor;
import '_shared.dart'
    show BeuiChartTicker, beuiChartColor, beuiChartFormatNumber;
import '_xy.dart';
import '_xy_parts.dart' show BeuiXYFocusOutline;

const double _sparklinePadding = 3;

/// A compact trend line for tables, stat cards, and inline text.
///
/// Missing and non-finite samples remain gaps. When [interactive] is enabled,
/// one keyboard- and screen-reader-accessible sample inspector is added.
class BeuiSparkline extends StatefulWidget {
  /// Creates a sparkline from samples in display order.
  const BeuiSparkline({
    required this.data,
    required this.label,
    super.key,
    this.labels,
    this.variant = BeuiSparklineVariant.line,
    this.curve = BeuiXYCurve.monotone,
    this.color = 'currentColor',
    this.height = 32,
    this.strokeWidth = 1.5,
    this.showDelta = false,
    this.invertDelta = false,
    this.interactive = false,
    this.formatValue,
  });

  /// Samples in display order. Null, short, and non-finite values are gaps.
  final List<num?> data;

  /// Optional sample labels, such as dates, used by interactive readout.
  final List<String>? labels;

  /// Accessible name, such as “Revenue, last 30 days”.
  final String label;

  /// Stroke-only or vertically faded area presentation.
  final BeuiSparklineVariant variant;

  /// Interpolation for each contiguous valid run.
  final BeuiXYCurve curve;

  /// A CSS-like color accepted by the shared chart color resolver.
  /// Defaults to the ambient text color.
  final String color;

  /// Plot height in logical pixels. Width follows its parent.
  final double height;

  /// Stroke thickness in logical pixels.
  final double strokeWidth;

  /// Whether to show the percentage change from the first to last present item.
  final bool showDelta;

  /// Treat a falling value as good and a rising value as bad.
  final bool invertDelta;

  /// Enables pointer, drag, and keyboard sample inspection.
  final bool interactive;

  /// Formats values for the accessible and inline readouts.
  final String Function(num value)? formatValue;

  @override
  State<BeuiSparkline> createState() => _BeuiSparklineState();
}

/// Sparkline stroke or faded-area variant.
enum BeuiSparklineVariant { line, area }

class _BeuiSparklineState extends State<BeuiSparkline> {
  int? _activeIndex;
  bool _open = false;
  bool _touching = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = BeuiColors.resolve(context);
    final inheritedColor =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    final color = widget.color.trim().toLowerCase() == 'currentcolor'
        ? inheritedColor
        : beuiChartColor(widget.color, colors, fallback: inheritedColor);
    final formatValue = widget.formatValue ?? _formatNumber;
    final values = widget.data
        .map<double?>((value) {
          if (value == null) return null;
          final number = value.toDouble();
          return number.isFinite ? number : null;
        })
        .toList(growable: false);
    final present = values.whereType<double>().toList(growable: false);
    final first = present.isEmpty ? null : present.first;
    final last = present.isEmpty ? null : present.last;
    final delta = first == null || first == 0 || last == null
        ? null
        : ((last - first).isFinite
                  ? (last - first) / first.abs()
                  : last / first.abs() - first.sign) *
              100;
    final trend = delta == null || delta.abs() < .05
        ? _SparklineTrend.flat
        : delta > 0
        ? _SparklineTrend.up
        : _SparklineTrend.down;
    final deltaText = delta == null
        ? null
        : '${trend == _SparklineTrend.up
              ? '+'
              : trend == _SparklineTrend.down
              ? '−'
              : ''}${delta.abs().toStringAsFixed(1)}%';
    final deltaColor = switch (trend) {
      _SparklineTrend.flat => colors.mutedForeground,
      _SparklineTrend.up when !widget.invertDelta => _emerald(context),
      _SparklineTrend.down when widget.invertDelta => _emerald(context),
      _SparklineTrend.up || _SparklineTrend.down => _rose(context),
    };
    final deltaBackground = switch (trend) {
      _SparklineTrend.flat => colors.muted,
      _SparklineTrend.up when !widget.invertDelta => const Color(0x1A00BC7D),
      _SparklineTrend.down when widget.invertDelta => const Color(0x1A00BC7D),
      _SparklineTrend.up || _SparklineTrend.down => const Color(0x1AFF2056),
    };
    final lastIndex = values.lastIndexWhere((value) => value != null);
    final activeIsValid =
        _activeIndex != null &&
        _activeIndex! >= 0 &&
        _activeIndex! < values.length &&
        values[_activeIndex!] != null;
    final inspecting = widget.interactive && _open && activeIsValid;
    // A gap selection retains its semantic “no data” value, while the visual
    // dot/readout fall back to the latest real sample just like the source.
    final displayedIndex = inspecting ? _activeIndex! : lastIndex;
    final displayedValue = displayedIndex < 0 ? null : values[displayedIndex];
    final summary = <String>[
      widget.label,
      if (first != null && last != null)
        'from ${formatValue(first)} to ${formatValue(last)}'
      else
        'no data',
      if (delta != null && trend != _SparklineTrend.flat)
        '${trend.name} ${delta.abs().toStringAsFixed(1)}%',
    ].join(', ');
    final canInspect = widget.interactive && present.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final lo = present.isEmpty ? 0.0 : present.reduce(math.min);
                final hi = present.isEmpty ? 1.0 : present.reduce(math.max);
                final range = hi == lo ? 1.0 : hi - lo;
                final scale = math.max(lo.abs(), hi.abs());
                double x(int index) =>
                    _sparklinePadding +
                    (values.length == 1
                        ? (width - _sparklinePadding * 2) / 2
                        : index /
                              (values.length - 1) *
                              (width - _sparklinePadding * 2));
                double y(double value) => hi == lo
                    ? widget.height / 2
                    : _sparklinePadding +
                          (range.isFinite
                                  ? (hi - value) / range
                                  : (hi / scale - value / scale) /
                                        (hi / scale - lo / scale)) *
                              (widget.height - _sparklinePadding * 2);
                final targets = <BeuiXYPointTarget>[
                  BeuiXYPointTarget(
                    key: 'baseline',
                    position: Offset(0, widget.height),
                  ),
                  for (var index = 0; index < values.length; index++)
                    if (values[index] != null)
                      BeuiXYPointTarget(
                        key: '$index',
                        position: Offset(x(index), y(values[index]!)),
                      ),
                ];
                if (width <= 0) return SizedBox(height: widget.height);
                return BeuiXYPointTracker(
                  targets: targets,
                  width: width,
                  reduceMotion: reduceMotion,
                  builder: (positions) {
                    final points = <BeuiXYPathPoint>[
                      for (var index = 0; index < values.length; index++)
                        values[index] == null ? null : positions['$index'],
                    ];
                    final baseline = positions['baseline']?.dy ?? widget.height;
                    final currentDot = displayedValue == null
                        ? null
                        : Offset(x(displayedIndex), y(displayedValue));
                    return SizedBox(
                      height: widget.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Semantics(
                            image: true,
                            label: summary,
                            child: CustomPaint(
                              painter: _SparklinePainter(
                                points: points,
                                baseline: baseline,
                                color: color,
                                variant: widget.variant,
                                curve: widget.curve,
                                strokeWidth: widget.strokeWidth,
                              ),
                            ),
                          ),
                          if (currentDot != null)
                            if (_touching || reduceMotion)
                              _SparklineDot(
                                position: currentDot,
                                color: color,
                                radius: inspecting ? 3.5 : 2.5,
                                strokeColor: colors.background,
                                strokeWidth: inspecting ? 2 : 0,
                              )
                            else
                              MotionBuilder<Offset>(
                                value: currentDot,
                                motion: motionFor(
                                  context,
                                  beuiSpringLayout,
                                  isMovement: true,
                                ),
                                converter: const OffsetMotionConverter(),
                                builder: (context, position, _) =>
                                    _SparklineDot(
                                      position: position,
                                      color: color,
                                      radius: inspecting ? 3.5 : 2.5,
                                      strokeColor: colors.background,
                                      strokeWidth: inspecting ? 2 : 0,
                                    ),
                              ),
                          if (canInspect)
                            BeuiXYFocusOutline(
                              offset: 2,
                              child: BeuiXYInspector(
                                count: values.length,
                                activeIndex: _activeIndex ?? -1,
                                onActiveIndexChanged: (index) =>
                                    setState(() => _activeIndex = index),
                                label: '${widget.label}: inspect samples',
                                valueText: (index) {
                                  final value = values[index];
                                  final name = _sampleName(
                                    widget.labels,
                                    index,
                                  );
                                  return '$name: ${value == null ? 'no data' : formatValue(value)}';
                                },
                                mode: BeuiXYInspectionMode.point,
                                open: _open,
                                onOpenChange: (open) =>
                                    setState(() => _open = open),
                                onTouchChange: (touching) =>
                                    setState(() => _touching = touching),
                                child: const SizedBox.expand(),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (canInspect) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Semantics(
                  hidden: !inspecting,
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (displayedValue != null)
                          ExcludeSemantics(
                            child: BeuiChartTicker(
                              value: displayedValue,
                              format: formatValue,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.25,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          )
                        else
                          const Text('No data', softWrap: false),
                        AnimatedOpacity(
                          opacity: inspecting ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          curve: beuiEaseOut,
                          child: ExcludeSemantics(
                            child: Text(
                              inspecting
                                  ? _sampleName(widget.labels, _activeIndex!)
                                  : '\u00a0',
                              softWrap: false,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.25,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (widget.showDelta && deltaText != null) ...[
            const SizedBox(width: 8),
            Semantics(
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: deltaBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  deltaText,
                  style: TextStyle(
                    color: deltaColor,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _SparklineTrend { flat, up, down }

// Source-parity exception to the BeuiColors rule: source `sparkline.tsx`
// hardcodes Tailwind emerald and rose for the delta badge, with separate
// light and dark shades. `BeuiColors.success` is one brightness-independent
// color, so it cannot reproduce them.
Color _emerald(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(
        0xFF00D492,
      ) // Tailwind 4 emerald-400, clipped sRGB conversion.
    : const Color(
        0xFF009966,
      ); // Tailwind 4 emerald-600, clipped sRGB conversion.

Color _rose(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFF637E) // Tailwind 4 rose-400, clipped sRGB conversion.
    : const Color(0xFFEC003F); // Tailwind 4 rose-600, clipped sRGB conversion.

String _formatNumber(num value) =>
    beuiChartFormatNumber(value, maximumFractionDigits: 2);

String _sampleName(List<String>? labels, int index) =>
    labels != null && index >= 0 && index < labels.length
    ? labels[index]
    : 'Sample ${index + 1}';

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.points,
    required this.baseline,
    required this.color,
    required this.variant,
    required this.curve,
    required this.strokeWidth,
  });

  final List<BeuiXYPathPoint> points;
  final double baseline;
  final Color color;
  final BeuiSparklineVariant variant;
  final BeuiXYCurve curve;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (variant == BeuiSparklineVariant.area) {
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .3), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size);
      canvas.drawPath(beuiXYAreaPath(points, baseline, curve: curve), fill);
    }
    canvas.drawPath(
      beuiXYLinePath(points, curve: curve),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.baseline != baseline ||
      oldDelegate.color != color ||
      oldDelegate.variant != variant ||
      oldDelegate.curve != curve ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _SparklineDot extends StatelessWidget {
  const _SparklineDot({
    required this.position,
    required this.color,
    required this.radius,
    required this.strokeColor,
    required this.strokeWidth,
  });

  final Offset position;
  final Color color;
  final double radius;
  final Color strokeColor;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => Positioned(
    left: position.dx - radius,
    top: position.dy - radius,
    width: radius * 2,
    height: radius * 2,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: strokeWidth == 0
            ? null
            : Border.all(color: strokeColor, width: strokeWidth),
      ),
    ),
  );
}
