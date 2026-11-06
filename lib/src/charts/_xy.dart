/// Shared model, geometry, inspection and point-motion primitives for XY charts.
///
/// This is an internal chart-family API. It mirrors the source implementation
/// in `components/charts/xy/{model,scale,path,use-inspection,use-points,inspector}`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/_engine.dart' show SingleMotionController;
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart' show BeuiChartTicker, beuiChartColor;

/// An indexed data series; values align with the category list by position.
@immutable
class BeuiXYSeries {
  const BeuiXYSeries({
    required this.id,
    required this.name,
    required this.color,
    required this.values,
  });

  final String id;
  final String name;
  final String color;
  final List<num?> values;
}

/// The normalized immutable counterpart to [BeuiXYSeries].
@immutable
class BeuiXYRow {
  BeuiXYRow({
    required this.id,
    required this.name,
    required this.color,
    required List<num?> values,
  }) : values = List.unmodifiable(values);

  final String id;
  final String name;
  final String color;
  final List<num?> values;
}

/// Source-supported path interpolation.
enum BeuiXYCurve { monotone, linear, step }

/// Normalized rows and unique category IDs, with first duplicate winning.
@immutable
class BeuiXYData {
  BeuiXYData({required List<BeuiXYRow> rows, required List<String> categories})
    : rows = List.unmodifiable(rows),
      categories = List.unmodifiable(categories);

  final List<BeuiXYRow> rows;
  final List<String> categories;
}

/// De-duplicates rows/categories by first occurrence while preserving each
/// category's original source index. Invalid, absent and optionally negative
/// samples are gaps, never coerced to zero.
BeuiXYData normalizeBeuiXY(
  List<BeuiXYSeries> series,
  List<String> categories, {
  bool nonnegative = false,
}) {
  final seenCategories = <String>{};
  final categoryIds = <String>[];
  final categoryPositions = <int>[];
  for (var i = 0; i < categories.length; i++) {
    if (seenCategories.add(categories[i])) {
      categoryIds.add(categories[i]);
      categoryPositions.add(i);
    }
  }
  final seenRows = <String>{};
  final rows = <BeuiXYRow>[];
  for (final row in series) {
    if (!seenRows.add(row.id)) continue;
    rows.add(
      BeuiXYRow(
        id: row.id,
        name: row.name,
        color: row.color,
        values: [
          for (final index in categoryPositions)
            if (index < row.values.length &&
                row.values[index] != null &&
                row.values[index]!.toDouble().isFinite &&
                (!nonnegative || row.values[index]! >= 0))
              row.values[index]
            else
              null,
        ],
      ),
    );
  }
  return BeuiXYData(rows: rows, categories: categoryIds);
}

/// A human-readable numeric domain with its tick positions.
@immutable
class BeuiXYDomain {
  BeuiXYDomain({
    required this.min,
    required this.max,
    required List<double> ticks,
  }) : ticks = List.unmodifiable(ticks);

  final double min;
  final double max;
  final List<double> ticks;

  double fraction(num value) {
    final span = max - min;
    if (span.isFinite) return (value - min) / span;
    final scale = math.max(min.abs(), max.abs());
    return (value / scale - min / scale) / (max / scale - min / scale);
  }
}

double _tidy(double value) => double.parse(value.toStringAsPrecision(12));

double _niceStep(double raw) {
  final power = math.pow(10.0, (math.log(raw) / math.ln10).floor()).toDouble();
  final fraction = raw / power;
  return (fraction <= 1
          ? 1
          : fraction <= 2
          ? 2
          : fraction <= 5
          ? 5
          : 10) *
      power;
}

/// Expands a value extent to source-compatible 1/2/5 × 10ⁿ ticks.
///
/// `fixed` bounds are retained exactly; malformed or non-finite bounds throw
/// [ArgumentError] instead of leaking an unusable geometry domain.
BeuiXYDomain niceBeuiXYDomain(
  List<num> values, {
  bool includeZero = false,
  int count = 4,
  (num, num)? fixed,
}) {
  if (count <= 0) throw ArgumentError.value(count, 'count', 'must be positive');
  if (fixed != null &&
      (!fixed.$1.toDouble().isFinite ||
          !fixed.$2.toDouble().isFinite ||
          fixed.$1 >= fixed.$2)) {
    throw ArgumentError.value(fixed, 'fixed', 'must be finite and ascending');
  }
  final finite = values
      .map((v) => v.toDouble())
      .where((v) => v.isFinite)
      .toList();
  var min =
      fixed?.$1.toDouble() ?? (finite.isEmpty ? 0 : finite.reduce(math.min));
  var max =
      fixed?.$2.toDouble() ?? (finite.isEmpty ? 1 : finite.reduce(math.max));
  if (includeZero && fixed == null) {
    min = math.min(0, min);
    max = math.max(0, max);
  }
  if (min == max) {
    if (min == 0) {
      max = 1;
    } else if (includeZero && min > 0) {
      min = 0;
    } else {
      final pad = min.abs() * .1;
      if ((min - pad).isFinite) min -= pad;
      if ((max + pad).isFinite) max += pad;
    }
  }
  final rawStep = (max - min) / count;
  if (!rawStep.isFinite || rawStep < 1e-300) {
    final scale = math.max(min.abs(), max.abs());
    final scaled = niceBeuiXYDomain(
      [min / scale, max / scale],
      count: count,
      fixed: fixed == null ? null : (min / scale, max / scale),
    );
    double restore(double value) =>
        (value * scale).clamp(-double.maxFinite, double.maxFinite);
    var lo = fixed?.$1.toDouble() ?? restore(scaled.min);
    var hi = fixed?.$2.toDouble() ?? restore(scaled.max);
    if (lo == hi) {
      lo = math.min(0, min);
      hi = math.max(0, max);
    }
    return BeuiXYDomain(
      min: lo,
      max: hi,
      ticks: scaled.ticks.map(restore).toSet().toList(),
    );
  }
  final step = _niceStep(rawStep);
  final lo = fixed == null ? _tidy((min / step).floor() * step) : min;
  final hi = fixed == null ? _tidy((max / step).ceil() * step) : max;
  if (lo >= hi || !lo.isFinite || !hi.isFinite) {
    return BeuiXYDomain(min: min, max: max, ticks: [min, max]);
  }
  final ticks = <double>[];
  for (
    var tick = (lo / step).ceil() * step;
    tick.isFinite && tick <= hi + step / 1e6;
    tick += step
  ) {
    ticks.add(_tidy(tick));
    if (tick + step <= tick) break;
  }
  return BeuiXYDomain(min: lo, max: hi, ticks: ticks);
}

/// Minimum index interval for labels with [minGap] pixels between neighbors.
int beuiXYLabelStride(int count, double length, {double minGap = 64}) {
  if (count <= 1 || length <= 0) return 1;
  return math.max(1, (count * minGap / length).ceil());
}

/// A coordinate or a gap in an XY path.
typedef BeuiXYPathPoint = Offset?;

List<List<Offset>> _runs(List<BeuiXYPathPoint> points) {
  final runs = <List<Offset>>[];
  var current = <Offset>[];
  for (final point in points) {
    if (point != null) {
      current.add(point);
    } else if (current.isNotEmpty) {
      runs.add(current);
      current = <Offset>[];
    }
  }
  if (current.isNotEmpty) runs.add(current);
  return runs;
}

double _roundPath(double value) => (value * 100 + .5).floorToDouble() / 100;

String _pathNumber(double value) {
  final rounded = _roundPath(value);
  return rounded == rounded.truncateToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

List<double> _tangents(List<Offset> run) {
  final n = run.length;
  final tangent = List<double>.filled(n, 0);
  for (var i = 1; i < n - 1; i++) {
    final h0 = run[i].dx - run[i - 1].dx;
    final h1 = run[i + 1].dx - run[i].dx;
    final s0 = h0 == 0 ? 0.0 : (run[i].dy - run[i - 1].dy) / h0;
    final s1 = h1 == 0 ? 0.0 : (run[i + 1].dy - run[i].dy) / h1;
    final p = h0 + h1 == 0 ? 0.0 : (s0 * h1 + s1 * h0) / (h0 + h1);
    final signSum = s0.sign + s1.sign;
    tangent[i] = signSum * math.min(math.min(s0.abs(), s1.abs()), .5 * p.abs());
  }
  double end(int a, int b, double neighbour) {
    final h = run[b].dx - run[a].dx;
    return h == 0
        ? neighbour
        : 3 * (run[b].dy - run[a].dy) / h / 2 - neighbour / 2;
  }

  tangent[0] = end(0, 1, tangent[1]);
  tangent[n - 1] = end(n - 2, n - 1, tangent[n - 2]);
  return tangent;
}

String _segmentData(List<Offset> run, BeuiXYCurve curve) {
  final first = run.first;
  var data = 'M${_pathNumber(first.dx)},${_pathNumber(first.dy)}';
  if (run.length == 1) return '${data}h0';
  if (curve == BeuiXYCurve.linear || run.length == 2) {
    for (final point in run.skip(1)) {
      data += 'L${_pathNumber(point.dx)},${_pathNumber(point.dy)}';
    }
    return data;
  }
  if (curve == BeuiXYCurve.step) {
    for (var i = 1; i < run.length; i++) {
      final mid = (run[i - 1].dx + run[i].dx) / 2;
      data += 'H${_pathNumber(mid)}V${_pathNumber(run[i].dy)}';
    }
    return '$data'
        'H${_pathNumber(run.last.dx)}';
  }
  final tangent = _tangents(run);
  for (var i = 1; i < run.length; i++) {
    final a = run[i - 1];
    final b = run[i];
    final dx = (b.dx - a.dx) / 3;
    data +=
        'C${_pathNumber(a.dx + dx)},${_pathNumber(a.dy + dx * tangent[i - 1])},'
        '${_pathNumber(b.dx - dx)},${_pathNumber(b.dy - dx * tangent[i])},'
        '${_pathNumber(b.dx)},${_pathNumber(b.dy)}';
  }
  return data;
}

/// Deterministic SVG-style path data counterpart used by fixture tests.
String beuiXYLinePathData(
  List<BeuiXYPathPoint> points, {
  BeuiXYCurve curve = BeuiXYCurve.monotone,
}) => _runs(points).map((run) => _segmentData(run, curve)).join();

/// Deterministic SVG-style area data; singleton runs have no fill.
String beuiXYAreaPathData(
  List<BeuiXYPathPoint> points,
  double baseline, {
  BeuiXYCurve curve = BeuiXYCurve.monotone,
}) => _runs(points)
    .where((run) => run.length > 1)
    .map(
      (run) =>
          '${_segmentData(run, curve)}L${_pathNumber(run.last.dx)},${_pathNumber(baseline)}'
          'L${_pathNumber(run.first.dx)},${_pathNumber(baseline)}Z',
    )
    .join();

Path beuiXYLinePath(
  List<BeuiXYPathPoint> points, {
  BeuiXYCurve curve = BeuiXYCurve.monotone,
}) => _buildPath(points, curve: curve);

Path beuiXYAreaPath(
  List<BeuiXYPathPoint> points,
  double baseline, {
  BeuiXYCurve curve = BeuiXYCurve.monotone,
}) => _buildPath(points, curve: curve, baseline: baseline);

Path _buildPath(
  List<BeuiXYPathPoint> points, {
  required BeuiXYCurve curve,
  double? baseline,
}) {
  final path = Path();
  for (final run in _runs(points)) {
    if (baseline != null && run.length == 1) continue;
    final first = run.first;
    path.moveTo(_roundPath(first.dx), _roundPath(first.dy));
    if (run.length == 1) {
      path.lineTo(_roundPath(first.dx), _roundPath(first.dy));
    } else if (curve == BeuiXYCurve.linear || run.length == 2) {
      for (final point in run.skip(1)) {
        path.lineTo(_roundPath(point.dx), _roundPath(point.dy));
      }
    } else if (curve == BeuiXYCurve.step) {
      for (var i = 1; i < run.length; i++) {
        final midpoint = _roundPath((run[i - 1].dx + run[i].dx) / 2);
        path.lineTo(midpoint, _roundPath(run[i - 1].dy));
        path.lineTo(midpoint, _roundPath(run[i].dy));
      }
      path.lineTo(_roundPath(run.last.dx), _roundPath(run.last.dy));
    } else {
      final tangent = _tangents(run);
      for (var i = 1; i < run.length; i++) {
        final a = run[i - 1];
        final b = run[i];
        final dx = (b.dx - a.dx) / 3;
        path.cubicTo(
          _roundPath(a.dx + dx),
          _roundPath(a.dy + dx * tangent[i - 1]),
          _roundPath(b.dx - dx),
          _roundPath(b.dy - dx * tangent[i]),
          _roundPath(b.dx),
          _roundPath(b.dy),
        );
      }
    }
    if (baseline != null) {
      path.lineTo(_roundPath(run.last.dx), _roundPath(baseline));
      path.lineTo(_roundPath(run.first.dx), _roundPath(baseline));
      path.close();
    }
  }
  return path;
}

/// One point's value and display color for a shared XY readout.
@immutable
class BeuiXYTooltipRow {
  const BeuiXYTooltipRow({
    required this.id,
    required this.name,
    required this.color,
    required this.value,
  });
  final String id;
  final String name;
  final String color;
  final num? value;
}

/// Shared tooltip rows; numeric values deliberately use [BeuiChartTicker].
class BeuiXYTooltipContent extends StatelessWidget {
  const BeuiXYTooltipContent({
    required this.title,
    required this.rows,
    required this.formatValue,
    this.total,
    this.compact = false,
    super.key,
  });
  final String title;
  final List<BeuiXYTooltipRow> rows;
  final String Function(num value) formatValue;
  final num? total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: compact ? 6 : 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.popoverForeground,
            ),
          ),
        ),
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) SizedBox(height: compact ? 4 : 6),
          _tooltipRow(rows[index], colors),
        ],
        if (total != null) ...[
          SizedBox(height: (compact ? 4 : 6) + 2),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BeuiChartTicker(
                    value: total!,
                    format: (value) => formatValue(value),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: compact
          ? const BoxConstraints(minWidth: 144, maxWidth: double.infinity)
          : const BoxConstraints.tightFor(width: 224),
      child: compact
          ? LayoutBuilder(
              builder: (context, constraints) => IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: math.min(144, constraints.maxWidth),
                    maxWidth: constraints.maxWidth,
                  ),
                  child: content,
                ),
              ),
            )
          : content,
    );
  }

  Widget _tooltipRow(BeuiXYTooltipRow row, BeuiColors colors) => Row(
    children: [
      Container(
        width: 4,
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: beuiChartColor(row.color, colors),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.mutedForeground),
          ),
        ),
      ),
      const SizedBox(width: 8),
      if (row.value == null)
        Text(
          'No data',
          style: TextStyle(fontSize: 11, color: colors.foreground),
        )
      else
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: BeuiChartTicker(
              value: row.value!,
              format: (value) => formatValue(value),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
    ],
  );
}

/// Point/band category inspector: one focus stop and semantic slider.
///
/// Pointer coordinates map directly to category samples/slots. Touch taps
/// retain the readout after pointer-up; cancellation closes it. Keyboard and
/// assistive-technology changes use the same controlled active index.
class BeuiXYInspector extends StatefulWidget {
  const BeuiXYInspector({
    required this.count,
    required this.activeIndex,
    required this.onActiveIndexChanged,
    required this.label,
    required this.valueText,
    required this.child,
    this.mode = BeuiXYInspectionMode.point,
    this.orientation = Axis.horizontal,
    this.open = false,
    this.onOpenChange,
    this.onTouchChange,
    this.onKeyboardInteraction,
    this.canHover = true,
    super.key,
  });

  final int count;
  final int activeIndex;
  final ValueChanged<int> onActiveIndexChanged;
  final String label;
  final String Function(int index) valueText;
  final Widget child;
  final BeuiXYInspectionMode mode;
  final Axis orientation;
  final bool open;
  final ValueChanged<bool>? onOpenChange;
  final ValueChanged<bool>? onTouchChange;
  final VoidCallback? onKeyboardInteraction;
  final bool canHover;

  @override
  State<BeuiXYInspector> createState() => _BeuiXYInspectorState();
}

enum BeuiXYInspectionMode { point, band }

class _BeuiXYInspectorState extends State<BeuiXYInspector> {
  final _focusNode = FocusNode();
  bool _pointerDriven = false;
  bool _focused = false;
  bool _mouseFocus = false;
  int? _last;
  int get _index => widget.activeIndex >= 0 && widget.activeIndex < widget.count
      ? widget.activeIndex
      : widget.count - 1;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _setOpen(bool value) {
    if (value != widget.open) widget.onOpenChange?.call(value);
  }

  void _step(int index) {
    if (widget.count == 0) return;
    widget.onActiveIndexChanged(index.clamp(0, widget.count - 1));
    _setOpen(true);
  }

  void _inspect(Offset position, Size size) {
    if (widget.count == 0) return;
    final length = widget.orientation == Axis.vertical
        ? size.height
        : size.width;
    if (length <= 0) return;
    final offset = widget.orientation == Axis.vertical
        ? position.dy
        : position.dx;
    final fraction = (offset / length).clamp(0.0, 1.0);
    final next = widget.mode == BeuiXYInspectionMode.point
        ? (fraction * (widget.count - 1)).round()
        : math.min(widget.count - 1, (fraction * widget.count).floor());
    widget.onActiveIndexChanged(next);
    if (_last != next) _setOpen(true);
    _last = next;
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.count == 0) {
      return KeyEventResult.ignored;
    }
    _pointerDriven = false;
    _mouseFocus = false;
    final key = event.logicalKey;
    widget.onKeyboardInteraction?.call();
    if (key == LogicalKeyboardKey.escape) {
      _setOpen(false);
      return KeyEventResult.handled;
    }
    final previous =
        key == LogicalKeyboardKey.arrowLeft ||
        (widget.orientation == Axis.vertical
            ? key == LogicalKeyboardKey.arrowUp
            : key == LogicalKeyboardKey.arrowDown);
    final next =
        key == LogicalKeyboardKey.arrowRight ||
        (widget.orientation == Axis.vertical
            ? key == LogicalKeyboardKey.arrowDown
            : key == LogicalKeyboardKey.arrowUp);
    if (key == LogicalKeyboardKey.home) {
      _step(0);
    } else if (key == LogicalKeyboardKey.end) {
      _step(widget.count - 1);
    } else if (previous) {
      _step(_index - 1);
    } else if (next) {
      _step(_index + 1);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _step(_index + math.max(1, ((widget.count - 1) / 10).round()));
    } else if (key == LogicalKeyboardKey.pageDown) {
      _step(_index - math.max(1, ((widget.count - 1) / 10).round()));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return widget.child;
    final index = _index;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onEnter: widget.canHover
              ? (event) => _inspect(event.localPosition, size)
              : null,
          onHover: widget.canHover
              ? (event) => _inspect(event.localPosition, size)
              : null,
          onExit: (_) {
            _last = null;
            if (!_focused || _pointerDriven || _mouseFocus) _setOpen(false);
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              _pointerDriven = true;
              _focusNode.requestFocus();
              _mouseFocus = event.kind != ui.PointerDeviceKind.touch;
              if (event.kind == ui.PointerDeviceKind.touch) {
                widget.onTouchChange?.call(true);
              }
              _last = null;
              _inspect(event.localPosition, size);
            },
            onPointerMove: (event) {
              if (event.kind == ui.PointerDeviceKind.touch
                  ? event.buttons != 0
                  : widget.canHover || event.buttons != 0) {
                _inspect(event.localPosition, size);
              }
            },
            onPointerUp: (event) {
              _pointerDriven = false;
              if (event.kind == ui.PointerDeviceKind.touch) {
                widget.onTouchChange?.call(false);
              }
            },
            onPointerCancel: (event) {
              _pointerDriven = false;
              if (event.kind == ui.PointerDeviceKind.touch) {
                widget.onTouchChange?.call(false);
              }
              _setOpen(false);
            },
            child: Focus(
              focusNode: _focusNode,
              onFocusChange: (focused) {
                _focused = focused;
                if (!focused) {
                  _mouseFocus = false;
                  _pointerDriven = false;
                  _setOpen(false);
                } else if (!_pointerDriven) {
                  _step(index);
                }
              },
              onKeyEvent: _key,
              child: Semantics(
                slider: true,
                label: widget.label,
                value: widget.valueText(index),
                increasedValue: widget.valueText(
                  math.min(widget.count - 1, index + 1),
                ),
                decreasedValue: widget.valueText(math.max(0, index - 1)),
                onIncrease: index < widget.count - 1
                    ? () {
                        widget.onKeyboardInteraction?.call();
                        _step(index + 1);
                      }
                    : null,
                onDecrease: index > 0
                    ? () {
                        widget.onKeyboardInteraction?.call();
                        _step(index - 1);
                      }
                    : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) => _inspect(details.localPosition, size),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Stable keyed point targets; x/y own independent source-layout springs.
@immutable
class BeuiXYPointTarget {
  const BeuiXYPointTarget({required this.key, required this.position});
  final String key;
  final Offset position;
}

/// Animated points shared by paths, dots and fills. Resizes snap; data changes
/// spring; reduced-motion updates snap. Unchanged keyed points are retained.
class BeuiXYPointTracker extends StatefulWidget {
  const BeuiXYPointTracker({
    required this.targets,
    required this.width,
    required this.reduceMotion,
    required this.builder,
    super.key,
  });

  final List<BeuiXYPointTarget> targets;
  final double width;
  final bool reduceMotion;
  final Widget Function(Map<String, Offset> positions) builder;

  @override
  State<BeuiXYPointTracker> createState() => _BeuiXYPointTrackerState();
}

class _BeuiXYPointTrackerState extends State<BeuiXYPointTracker>
    with TickerProviderStateMixin {
  final _positions =
      <String, (SingleMotionController, SingleMotionController)>{};
  final _commanded = <SingleMotionController, double>{};
  double? _lastWidth;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BeuiXYPointTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sync() {
    final byKey = <String, BeuiXYPointTarget>{};
    for (final target in widget.targets) {
      byKey.putIfAbsent(target.key, () => target);
    }
    for (final key in _positions.keys.toList()) {
      if (!byKey.containsKey(key)) {
        final pair = _positions.remove(key)!;
        _commanded.remove(pair.$1);
        _commanded.remove(pair.$2);
        pair.$1.dispose();
        pair.$2.dispose();
      }
    }
    final resized = _lastWidth != null && _lastWidth != widget.width;
    _lastWidth = widget.width;
    for (final target in byKey.values) {
      final pair = _positions.putIfAbsent(
        target.key,
        () => (
          SingleMotionController(
            motion: beuiSpringLayout,
            vsync: this,
            initialValue: target.position.dx,
          )..addListener(_changed),
          SingleMotionController(
            motion: beuiSpringLayout,
            vsync: this,
            initialValue: target.position.dy,
          )..addListener(_changed),
        ),
      );
      for (final axis in [
        (pair.$1, target.position.dx),
        (pair.$2, target.position.dy),
      ]) {
        if (widget.reduceMotion || resized) {
          axis.$1.stop();
          if (axis.$1.value != axis.$2) axis.$1.value = axis.$2;
        } else if (_commanded[axis.$1] != axis.$2) {
          axis.$1.animateTo(axis.$2);
        }
        _commanded[axis.$1] = axis.$2;
      }
    }
  }

  @override
  void dispose() {
    for (final pair in _positions.values) {
      pair.$1.dispose();
      pair.$2.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder({
    for (final entry in _positions.entries)
      entry.key: Offset(entry.value.$1.value, entry.value.$2.value),
  });
}
