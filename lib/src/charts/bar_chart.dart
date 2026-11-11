/// Responsive, composable grouped and stacked bar charts.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../motion/_engine.dart'
    show
        MotionBuilder,
        OffsetMotionConverter,
        RectMotionConverter,
        SingleMotionController;
import '../motion/_scroll_geometry.dart';
import '../motion/tooltip.dart' show BeuiTooltip, BeuiTooltipSide;
import '../theme/beui_colors.dart';
import '../tokens/motion.dart' show beuiEaseOut, beuiSpringLayout, motionFor;
import '_shared.dart';
import '_xy.dart';
import '_xy_parts.dart';

/// Public series type used by [BeuiBarChart].
typedef BeuiBarChartSeries = BeuiXYSeries;

/// Grouped bars share a baseline; stacked bars accumulate visible values.
enum BeuiBarChartLayout { grouped, stacked }

/// Bars extend upward or to the right.
enum BeuiBarChartOrientation { vertical, horizontal }

/// Category order based on the sum of visible values.
enum BeuiBarChartSort { none, ascending, descending }

/// Data passed to a custom [BeuiBarChartTooltip] renderer.
@immutable
class BeuiBarChartTooltipData {
  const BeuiBarChartTooltipData({
    required this.category,
    required this.index,
    required this.rows,
    required this.total,
  });

  final String category;
  final int index;
  final List<BeuiXYTooltipRow> rows;
  final num total;
}

/// State shared by the composable Bar chart parts.
@immutable
class BeuiBarChartModel {
  const BeuiBarChartModel._({
    required this.rows,
    required this.categories,
    required this.visibleRows,
    required this.hiddenSeries,
    required this.activeId,
    required this.activeIndex,
    required this.open,
    required this.touching,
    required this.layout,
    required this.orientation,
    required this.sort,
    required this.order,
    required this.totals,
    required this.domain,
    required this.label,
    required this.formatValue,
    required this.formatTick,
    required this.highlightedSeries,
    required this.canHover,
    required this.onActive,
    required this.onOpen,
    required this.onTouch,
    required this.onToggleSeries,
    required this.onHoverSeries,
    required this.tooltipAnchor,
    required this.tooltipAnchorLink,
    required this.pointerPosition,
    required this.onPointerPosition,
  });

  final List<BeuiXYRow> rows;
  final List<String> categories;
  final List<BeuiXYRow> visibleRows;
  final List<String> hiddenSeries;
  final String? activeId;
  final int activeIndex;
  final bool open;
  final bool touching;
  final BeuiBarChartLayout layout;
  final BeuiBarChartOrientation orientation;
  final BeuiBarChartSort sort;
  final List<int> order;
  final List<double> totals;
  final BeuiXYDomain domain;
  final String label;
  final String Function(num) formatValue;
  final String Function(num) formatTick;
  final String? highlightedSeries;
  final bool canHover;
  final ValueChanged<String?> onActive;
  final ValueChanged<bool> onOpen;
  final ValueChanged<bool> onTouch;
  final ValueChanged<String> onToggleSeries;
  final ValueChanged<String?> onHoverSeries;
  final GlobalKey tooltipAnchor;
  final LayerLink tooltipAnchorLink;
  final Offset? pointerPosition;
  final ValueChanged<Offset?> onPointerPosition;
}

/// Composable bar chart. Omit [child] for plot, tooltip, and multi-row legend.
class BeuiBarChart extends StatefulWidget {
  const BeuiBarChart({
    required this.series,
    required this.categories,
    super.key,
    this.layout = BeuiBarChartLayout.grouped,
    this.orientation = BeuiBarChartOrientation.vertical,
    this.sort = BeuiBarChartSort.none,
    this.max,
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.controlledActive = false,
    this.hiddenSeries,
    this.defaultHiddenSeries = const [],
    this.onHiddenSeriesChange,
    this.controlledHiddenSeries = false,
    this.formatValue,
    this.formatTick,
    this.label = 'Bar chart',
    this.child,
  });

  /// Accesses the closest chart state for custom compositions.
  static BeuiBarChartModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_BarChartScope>();
    if (scope == null) {
      throw FlutterError(
        'Bar chart parts must be rendered inside BeuiBarChart.',
      );
    }
    return scope.model;
  }

  final List<BeuiBarChartSeries> series;
  final List<String> categories;
  final BeuiBarChartLayout layout;
  final BeuiBarChartOrientation orientation;
  final BeuiBarChartSort sort;

  /// Positive fixed upper bound. Non-positive and non-finite values are ignored.
  final num? max;

  /// Controlled category ID. [controlledActive] permits explicitly controlling null.
  final String? activeId;
  final String? defaultActiveId;
  final ValueChanged<String?>? onActiveChange;
  final bool controlledActive;
  final List<String>? hiddenSeries;
  final List<String> defaultHiddenSeries;
  final ValueChanged<List<String>>? onHiddenSeriesChange;
  final bool controlledHiddenSeries;
  final String Function(num value)? formatValue;
  final String Function(num value)? formatTick;
  final String label;

  /// Custom chart composition. The data table is retained beneath it.
  final Widget? child;

  @override
  State<BeuiBarChart> createState() => _BeuiBarChartState();
}

class _BarChartScope extends InheritedWidget {
  const _BarChartScope({required this.model, required super.child});
  final BeuiBarChartModel model;
  @override
  bool updateShouldNotify(_BarChartScope oldWidget) => model != oldWidget.model;
}

class _BeuiBarChartState extends State<BeuiBarChart> {
  String? _internalActive;
  late List<String> _internalHidden;
  bool _open = false;
  bool _touching = false;
  String? _hoveredSeries;
  final _tooltipAnchor = GlobalKey(debugLabel: 'bar-chart-tooltip-anchor');
  final _tooltipAnchorLink = LayerLink();
  Offset? _pointerPosition;

  bool get _activeControlled =>
      widget.controlledActive || widget.activeId != null;
  bool get _hiddenControlled =>
      widget.controlledHiddenSeries || widget.hiddenSeries != null;
  String? get _requestedActive =>
      _activeControlled ? widget.activeId : _internalActive;
  List<String> get _requestedHidden =>
      _hiddenControlled ? widget.hiddenSeries ?? const [] : _internalHidden;

  @override
  void initState() {
    super.initState();
    _internalActive = widget.defaultActiveId;
    _internalHidden = List.unmodifiable(widget.defaultHiddenSeries);
  }

  @override
  void didUpdateWidget(covariant BeuiBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activeControlled &&
        _internalActive != null &&
        !widget.categories.contains(_internalActive)) {
      _internalActive = null;
      _open = false;
    }
    final ids = widget.series.map((row) => row.id).toSet();
    if (_hoveredSeries != null && !ids.contains(_hoveredSeries)) {
      _hoveredSeries = null;
    }
  }

  void _setActive(String? next, List<String> categories) {
    final valid = next != null && categories.contains(next) ? next : null;
    final previous = _requestedActive;
    if (!_activeControlled && _internalActive != valid) {
      setState(() => _internalActive = valid);
    }
    if (previous != valid) widget.onActiveChange?.call(valid);
  }

  void _toggleHidden(String id) {
    final current = _requestedHidden;
    final next = List<String>.unmodifiable(
      current.contains(id)
          ? current.where((item) => item != id)
          : [...current, id],
    );
    if (!_hiddenControlled) setState(() => _internalHidden = next);
    if (current.length != next.length) widget.onHiddenSeriesChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final data = normalizeBeuiXY(
      widget.series,
      widget.categories,
      nonnegative: true,
    );
    final hidden = _requestedHidden;
    final visible = data.rows.where((row) => !hidden.contains(row.id)).toList();
    final totals = List<double>.generate(
      data.categories.length,
      // Values are nonnegative, so clamping keeps an overflowing stack finite.
      (i) => visible.fold<double>(
        0,
        (sum, row) => math.min(sum + (row.values[i] ?? 0), double.maxFinite),
      ),
    );
    final order = List<int>.generate(data.categories.length, (i) => i);
    if (widget.sort != BeuiBarChartSort.none) {
      order.sort((a, b) {
        final comparison = widget.sort == BeuiBarChartSort.ascending
            ? totals[a].compareTo(totals[b])
            : totals[b].compareTo(totals[a]);
        return comparison == 0 ? a.compareTo(b) : comparison;
      });
    }
    final extent = widget.layout == BeuiBarChartLayout.stacked
        ? totals
        : visible
              .expand(
                (row) => row.values.whereType<num>().map((v) => v.toDouble()),
              )
              .toList();
    final fixed =
        widget.max != null && widget.max!.toDouble().isFinite && widget.max! > 0
        ? (0, widget.max!)
        : null;
    final domain = niceBeuiXYDomain(extent, includeZero: true, fixed: fixed);
    final requested = _requestedActive;
    final active = requested != null && data.categories.contains(requested)
        ? requested
        : null;
    final highlighted = _hoveredSeries;
    final model = BeuiBarChartModel._(
      rows: data.rows,
      categories: data.categories,
      visibleRows: List.unmodifiable(visible),
      hiddenSeries: List.unmodifiable(hidden),
      activeId: active,
      activeIndex: active == null ? -1 : data.categories.indexOf(active),
      open: _open && active != null,
      touching: _touching,
      layout: widget.layout,
      orientation: widget.orientation,
      sort: widget.sort,
      order: List.unmodifiable(order),
      totals: List.unmodifiable(totals),
      domain: domain,
      label: widget.label,
      formatValue:
          widget.formatValue ??
          (value) => beuiChartFormatNumber(value, maximumFractionDigits: 2),
      formatTick:
          widget.formatTick ??
          (value) => beuiChartFormatNumber(
            value,
            maximumFractionDigits: 1,
            compact: true,
          ),
      highlightedSeries: visible.any((r) => r.id == highlighted)
          ? highlighted
          : null,
      canHover:
          kIsWeb ||
          switch (defaultTargetPlatform) {
            TargetPlatform.macOS ||
            TargetPlatform.linux ||
            TargetPlatform.windows => true,
            _ => false,
          },
      onActive: (id) => _setActive(id, data.categories),
      onOpen: (value) {
        if (_open != value) setState(() => _open = value);
      },
      onTouch: (value) {
        if (_touching != value) setState(() => _touching = value);
      },
      onToggleSeries: _toggleHidden,
      onHoverSeries: (id) => setState(() => _hoveredSeries = id),
      tooltipAnchor: _tooltipAnchor,
      tooltipAnchorLink: _tooltipAnchorLink,
      pointerPosition: _pointerPosition,
      onPointerPosition: (position) {
        if (_pointerPosition != position) {
          setState(() => _pointerPosition = position);
        }
      },
    );
    return _BarChartScope(
      model: model,
      child: Semantics(
        container: true,
        label: widget.label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.child != null)
              widget.child!
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BeuiBarChartPlot(),
                  const SizedBox(height: 12),
                  const BeuiBarChartTooltip(),
                  if (data.rows.length > 1) ...[
                    const SizedBox(height: 12),
                    const BeuiBarChartLegend(),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            BeuiXYDataTable(
              label: widget.label,
              rows: data.rows,
              categories: data.categories,
              formatValue: model.formatValue,
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive bar plot with grouped/stacked layouts and band inspection.
class BeuiBarChartPlot extends StatefulWidget {
  const BeuiBarChartPlot({
    super.key,
    this.height,
    this.labelWidth = 96,
    this.showGrid = true,
  });
  final double? height;
  final double labelWidth;
  final bool showGrid;
  @override
  State<BeuiBarChartPlot> createState() => _BeuiBarChartPlotState();
}

class _BeuiBarChartPlotState extends State<BeuiBarChartPlot>
    with ScrollGeometryMixin<BeuiBarChartPlot> {
  static const _valueGutter = 44.0;
  static const _top = 12.0;
  static const _right = 12.0;
  static const _bottom = 0.0;
  static const _fill = .7;
  static const _gap = 3.0;
  static const _maxBar = 32.0;
  static const _maxStack = 56.0;
  final _plotKey = GlobalKey(debugLabel: 'bar-chart-plot-viewport');
  bool _entered = false;
  bool _introActive = true;
  Timer? _introTimer;

  @override
  void onScrollGeometryChanged() => _checkInView();
  @override
  void dispose() {
    _introActive = false;
    _introTimer?.cancel();
    super.dispose();
  }

  void _checkInView() {
    if (_entered || !mounted) return;
    if ((_plotVisibleFraction() ?? 0) >= .3) {
      setState(() => _entered = true);
      _introTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _introActive = false);
      });
    }
  }

  double? _plotVisibleFraction() {
    final box = _plotKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.height <= 0) return null;
    final scrollTop = topInViewport;
    final scrollHeight = viewportHeight;
    final top = scrollTop ?? box.localToGlobal(Offset.zero).dy;
    final viewport = scrollHeight ?? MediaQuery.sizeOf(context).height;
    if (viewport <= 0) return 0;
    final visible =
        (top + box.size.height).clamp(0.0, viewport) - top.clamp(0.0, viewport);
    return (visible / box.size.height).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInView();
      onScrollGeometryChanged();
    });
    final model = BeuiBarChart.of(context);
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final vertical = model.orientation == BeuiBarChartOrientation.vertical;
    final count = model.categories.length;
    final height =
        widget.height ?? (vertical ? 288.0 : math.max(160.0, count * 36.0));
    if (count == 0 || model.rows.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 640.0;
        final bandStart = vertical ? _valueGutter : 0.0;
        final bandLength = vertical
            ? math.max(0.0, width - _valueGutter - _right)
            : height;
        final valueStart = vertical ? height - _bottom : widget.labelWidth;
        final valueLength = vertical
            ? height - _top - _bottom
            : math.max(0.0, width - widget.labelWidth - 2 * _right);
        final slot = bandLength / count;
        final maxValue = model.domain.max == 0 ? 1.0 : model.domain.max;
        double scale(num value) {
          final ratio = value.toDouble() / maxValue;
          // Keep overflow geometry beyond the viewport clip and bar end cap.
          final maxRatio = 1 + 40 / math.max(valueLength, 1);
          return (ratio.isFinite ? math.min(ratio, maxRatio) : maxRatio) *
              valueLength;
        }

        double valueAt(num value) =>
            vertical ? valueStart - scale(value) : valueStart + scale(value);
        final visible = model.visibleRows;
        final grouped = model.layout == BeuiBarChartLayout.grouped;
        final nRows = math.max(1, visible.length);
        final thickness = grouped
            ? math
                  .max(
                    1,
                    math.min(
                      _maxBar,
                      (slot * _fill - (nRows - 1) * _gap) / nRows,
                    ),
                  )
                  .toDouble()
            : math.max(1, math.min(_maxStack, slot * _fill)).toDouble();
        final activeRank = model.activeIndex < 0
            ? -1
            : model.order.indexOf(model.activeIndex);
        final safeIndex = model.activeIndex.clamp(0, count - 1);
        final reach = model.layout == BeuiBarChartLayout.stacked
            ? model.totals[safeIndex]
            : visible.fold<double>(
                0,
                (largest, row) =>
                    math.max(largest, row.values[safeIndex]?.toDouble() ?? 0),
              );
        final endpointFraction = model.domain.max == 0
            ? 0.0
            : (reach / model.domain.max).clamp(0.0, 1.0);
        final tooltipEndpoint = vertical
            ? Offset(
                bandStart + (activeRank + .5) * slot,
                _top + valueLength * (1 - endpointFraction),
              )
            : Offset(
                valueStart + valueLength * endpointFraction,
                (activeRank + .5) * slot,
              );
        final tooltipPosition = model.pointerPosition ?? tooltipEndpoint;
        final stride = beuiXYLabelStride(
          count,
          bandLength,
          minGap: vertical ? 56 : 18,
        );
        final plot = SizedBox(
          key: _plotKey,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: BeuiXYAxisLayer(
                    ticks: model.domain.ticks,
                    position: (v) => valueAt(v),
                    axis: vertical ? Axis.vertical : Axis.horizontal,
                    from: vertical ? bandStart : 0,
                    to: vertical ? bandStart + bandLength : height,
                    labelOffset: vertical ? _valueGutter : 0,
                    format: model.formatTick,
                    showGrid: widget.showGrid,
                    showLabels: vertical,
                    reduceMotion: reduce,
                  ),
                ),
              ),
              _BarInspectionBand(
                rect: Rect.fromLTWH(
                  vertical
                      ? bandStart + math.max(activeRank, 0) * slot
                      : valueStart,
                  vertical ? _top : math.max(activeRank, 0) * slot,
                  vertical ? slot : valueLength + _right,
                  vertical ? valueLength : slot,
                ),
                visible: model.open && activeRank >= 0,
                snap: model.touching || reduce,
                color: colors.foreground,
              ),
              if (!vertical)
                for (var rank = 0; rank < count; rank++)
                  if (rank % stride == 0)
                    _BarCategoryLabel(
                      key: ValueKey(model.categories[model.order[rank]]),
                      target: Offset(0, rank * slot),
                      width: widget.labelWidth,
                      height: slot,
                      snap: reduce,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            model.categories[model.order[rank]],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
              Positioned.fill(
                child: ClipRect(
                  clipper: _BarMarkClipper(
                    vertical: vertical,
                    valueStart: valueStart,
                  ),
                  child: Stack(
                    children: [
                      for (var rank = 0; rank < count; rank++)
                        _BarCategoryGroup(
                          key: ValueKey(model.categories[model.order[rank]]),
                          rank: rank,
                          categoryIndex: model.order[rank],
                          slot: slot,
                          bandStart: bandStart,
                          valueStart: valueStart,
                          valueLength: valueLength,
                          vertical: vertical,
                          grouped: grouped,
                          thickness: thickness,
                          scale: scale,
                          rows: model.rows,
                          hidden: model.hiddenSeries.toSet(),
                          highlighted: model.highlightedSeries,
                          visibleRows: visible,
                          reduceMotion: reduce,
                          revealed: _entered || reduce,
                          delay: reduce || !_introActive
                              ? Duration.zero
                              : Duration(
                                  milliseconds: math.min(rank * 35, 400),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
              if (model.activeIndex >= 0 && model.activeIndex < count)
                Positioned(
                  left: tooltipPosition.dx,
                  top: tooltipPosition.dy,
                  child: CompositedTransformTarget(
                    key: model.tooltipAnchor,
                    link: model.tooltipAnchorLink,
                    child: const SizedBox.shrink(),
                  ),
                ),
              Positioned(
                key: const ValueKey('bar-inspection'),
                left: vertical ? bandStart : valueStart,
                top: vertical ? _top : 0,
                width: vertical ? bandLength : valueLength,
                height: vertical ? valueLength : bandLength,
                child: BeuiXYFocusOutline(
                  child: BeuiXYInspector(
                    count: count,
                    activeIndex: activeRank,
                    onActiveIndexChanged: (rank) =>
                        model.onActive(model.categories[model.order[rank]]),
                    label: '${model.label}: inspect categories',
                    valueText: (rank) {
                      final i = model.order[rank];
                      return [
                        model.categories[i],
                        for (final row in visible)
                          '${row.name} ${row.values[i] == null ? 'no data' : model.formatValue(row.values[i]!)}',
                        if (model.layout == BeuiBarChartLayout.stacked &&
                            visible.length > 1)
                          'Total ${model.formatValue(model.totals[i])}',
                      ].join('. ');
                    },
                    mode: BeuiXYInspectionMode.band,
                    orientation: vertical ? Axis.horizontal : Axis.vertical,
                    open: model.open,
                    onOpenChange: model.onOpen,
                    onTouchChange: model.onTouch,
                    onKeyboardInteraction: () => model.onPointerPosition(null),
                    canHover: model.canHover,
                    child: Listener(
                      onPointerDown: (event) => model.onPointerPosition(
                        Offset(
                          (vertical ? bandStart : valueStart) +
                              event.localPosition.dx,
                          (vertical ? _top : 0) + event.localPosition.dy,
                        ),
                      ),
                      onPointerMove: (event) => model.onPointerPosition(
                        Offset(
                          (vertical ? bandStart : valueStart) +
                              event.localPosition.dx,
                          (vertical ? _top : 0) + event.localPosition.dy,
                        ),
                      ),
                      onPointerUp: (event) {
                        if (event.kind != PointerDeviceKind.touch) {
                          model.onPointerPosition(null);
                        }
                      },
                      onPointerCancel: (_) => model.onPointerPosition(null),
                      child: MouseRegion(
                        onHover: (event) => model.onPointerPosition(
                          Offset(
                            (vertical ? bandStart : valueStart) +
                                event.localPosition.dx,
                            (vertical ? _top : 0) + event.localPosition.dy,
                          ),
                        ),
                        onExit: (_) {
                          if (!model.touching) model.onPointerPosition(null);
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            plot,
            SizedBox(
              height: 24,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (vertical) ...[
                    for (var rank = 0; rank < count; rank++)
                      if (rank % stride == 0)
                        _BarCategoryLabel(
                          key: ValueKey(model.categories[model.order[rank]]),
                          target: Offset(
                            bandStart + (rank + .5) * slot - slot * stride / 2,
                            8,
                          ),
                          width: slot * stride,
                          height: 16,
                          snap: reduce,
                          child: Text(
                            model.categories[model.order[rank]],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                  ] else
                    BeuiXYAxisLayer(
                      ticks: model.domain.ticks,
                      position: valueAt,
                      axis: Axis.horizontal,
                      from: 0,
                      to: 0,
                      labelOffset: 8,
                      format: model.formatTick,
                      showGrid: false,
                      showLabels: true,
                      reduceMotion: reduce,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BarCategoryLabel extends StatelessWidget {
  const _BarCategoryLabel({
    required this.target,
    required this.width,
    required this.height,
    required this.snap,
    required this.child,
    super.key,
  });

  final Offset target;
  final double width, height;
  final bool snap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = snap
        ? Transform.translate(offset: target, child: child)
        : MotionBuilder<Offset>(
            value: target,
            motion: motionFor(context, beuiSpringLayout, isMovement: true),
            converter: const OffsetMotionConverter(),
            builder: (context, offset, inner) =>
                Transform.translate(offset: offset, child: inner),
            child: child,
          );
    return Positioned(
      left: 0,
      top: 0,
      width: width,
      height: height,
      child: label,
    );
  }
}

class _BarMarkClipper extends CustomClipper<Rect> {
  const _BarMarkClipper({required this.vertical, required this.valueStart});

  final bool vertical;
  final double valueStart;

  @override
  Rect getClip(Size size) => vertical
      ? Rect.fromLTRB(0, -16, size.width, valueStart)
      : Rect.fromLTRB(valueStart, 0, size.width, size.height);

  @override
  bool shouldReclip(_BarMarkClipper oldClipper) =>
      vertical != oldClipper.vertical || valueStart != oldClipper.valueStart;
}

class _BarInspectionBand extends StatelessWidget {
  const _BarInspectionBand({
    required this.rect,
    required this.visible,
    required this.snap,
    required this.color,
  });

  final Rect rect;
  final bool visible;
  final bool snap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final band = IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        curve: beuiEaseOut,
        opacity: visible ? .05 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
    if (snap) return Positioned.fromRect(rect: rect, child: band);
    return BeuiChartSpringRect(
      value: rect,
      builder: (context, current) =>
          Positioned.fromRect(rect: current, child: band),
    );
  }
}

class _BarCategoryGroup extends StatefulWidget {
  const _BarCategoryGroup({
    super.key,
    required this.rank,
    required this.categoryIndex,
    required this.slot,
    required this.bandStart,
    required this.valueStart,
    required this.valueLength,
    required this.vertical,
    required this.grouped,
    required this.thickness,
    required this.scale,
    required this.rows,
    required this.hidden,
    required this.highlighted,
    required this.visibleRows,
    required this.reduceMotion,
    required this.revealed,
    required this.delay,
  });

  final int rank, categoryIndex;
  final double slot, bandStart, valueStart, valueLength, thickness;
  final bool vertical, grouped, reduceMotion, revealed;
  final Duration delay;
  final double Function(num) scale;
  final List<BeuiXYRow> rows, visibleRows;
  final Set<String> hidden;
  final String? highlighted;

  @override
  State<_BarCategoryGroup> createState() => _BarCategoryGroupState();
}

class _BarCategoryGroupState extends State<_BarCategoryGroup>
    with TickerProviderStateMixin {
  late final SingleMotionController _x = SingleMotionController(
    motion: beuiSpringLayout,
    vsync: this,
    initialValue: _positionFor(widget).dx,
  );
  late final SingleMotionController _y = SingleMotionController(
    motion: beuiSpringLayout,
    vsync: this,
    initialValue: _positionFor(widget).dy,
  );
  late final Listenable _position = Listenable.merge([_x, _y]);

  static Offset _positionFor(_BarCategoryGroup widget) => Offset(
    widget.vertical
        ? widget.bandStart + widget.rank * widget.slot
        : widget.valueStart,
    widget.vertical ? 12 : widget.rank * widget.slot,
  );

  @override
  void didUpdateWidget(covariant _BarCategoryGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _positionFor(widget);
    if (widget.reduceMotion) {
      _x.stop();
      _y.stop();
      _x.value = target.dx;
      _y.value = target.dy;
    } else if (_positionFor(oldWidget) != target) {
      _x.animateTo(target.dx);
      _y.animateTo(target.dy);
    }
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.max(1, widget.visibleRows.length);
    final rowWidth = widget.grouped
        ? math.max(
            1.0,
            math.min(
              32.0,
              (widget.slot * .7 - (visibleCount - 1) * 3) / visibleCount,
            ),
          )
        : widget.thickness;
    final groupWidth = widget.grouped
        ? visibleCount * rowWidth + (visibleCount - 1) * 3
        : widget.thickness;
    final capId = widget.rows.reversed
        .where(
          (row) =>
              !widget.hidden.contains(row.id) &&
              (row.values[widget.categoryIndex] ?? 0) > 0,
        )
        .firstOrNull
        ?.id;
    return AnimatedBuilder(
      animation: _position,
      builder: (context, _) {
        var stackedLength = 0.0;
        var visibleIndex = 0;
        final marks = <Widget>[];
        for (final row in widget.rows) {
          final hidden = widget.hidden.contains(row.id);
          final value = hidden
              ? 0.0
              : (row.values[widget.categoryIndex] ?? 0).toDouble();
          final length = widget.scale(value);
          final start = widget.grouped ? 0.0 : stackedLength;
          final offset =
              (widget.slot - groupWidth) / 2 +
              (widget.grouped
                  ? (hidden
                            ? (widget.visibleRows.length - 1) / 2
                            : visibleIndex) *
                        (rowWidth + 3)
                  : 0);
          final radius = widget.grouped || capId == row.id
              ? math.min(4.0, rowWidth / 2).toDouble()
              : 0.0;
          final end = start + length;
          final bodyLength = math.max(.0001, length - radius);
          final bodyRect = widget.vertical
              ? Rect.fromLTWH(
                  offset,
                  widget.valueLength - end + radius,
                  rowWidth,
                  bodyLength,
                )
              : Rect.fromLTWH(start, offset, bodyLength, rowWidth);
          final baselineRect = widget.vertical
              ? Rect.fromLTWH(offset, widget.valueLength, rowWidth, .0001)
              : Rect.fromLTWH(0, offset, .0001, rowWidth);
          final capOffset = widget.vertical
              ? Offset(offset, widget.valueLength - end)
              : Offset(end - 2 * radius, offset);
          final baselineCapOffset = widget.vertical
              ? Offset(offset, widget.valueLength)
              : Offset(0, offset);
          final shown = value > 0 && !hidden;
          final opacity =
              widget.highlighted != null && widget.highlighted != row.id
              ? .25
              : 1.0;
          marks.add(
            _BarMark(
              key: ValueKey('bar-mark-${row.id}'),
              bodyRect: bodyRect,
              baselineRect: baselineRect,
              capOffset: capOffset,
              baselineCapOffset: baselineCapOffset,
              radius: radius,
              thickness: rowWidth,
              vertical: widget.vertical,
              color: row.color,
              opacity: shown ? opacity : 0,
              reduceMotion: widget.reduceMotion,
              revealed: widget.revealed,
              delay: widget.delay,
            ),
          );
          if (!hidden) {
            stackedLength += length;
            visibleIndex++;
          }
        }
        return Positioned(
          left: _x.value,
          top: _y.value,
          width: widget.vertical ? widget.slot : widget.valueLength,
          height: widget.vertical ? widget.valueLength : widget.slot,
          child: Stack(clipBehavior: Clip.none, children: marks),
        );
      },
    );
  }
}

class _BarMark extends StatefulWidget {
  const _BarMark({
    required this.bodyRect,
    required this.baselineRect,
    required this.capOffset,
    required this.baselineCapOffset,
    required this.radius,
    required this.thickness,
    required this.vertical,
    required this.color,
    required this.opacity,
    required this.reduceMotion,
    required this.revealed,
    required this.delay,
    super.key,
  });

  final Rect bodyRect, baselineRect;
  final Offset capOffset, baselineCapOffset;
  final double radius, thickness, opacity;
  final bool vertical, reduceMotion, revealed;
  final String color;
  final Duration delay;

  @override
  State<_BarMark> createState() => _BarMarkState();
}

class _BarMarkState extends State<_BarMark> {
  Timer? _delayTimer;
  late bool _ready = widget.delay == Duration.zero && widget.revealed;

  @override
  void initState() {
    super.initState();
    if (widget.revealed && !widget.reduceMotion && !_ready) {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  void _reveal() {
    _delayTimer?.cancel();
    if (widget.reduceMotion || widget.delay == Duration.zero) {
      if (!_ready) setState(() => _ready = true);
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void didUpdateWidget(covariant _BarMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion) {
      _delayTimer?.cancel();
      if (!_ready) _ready = true;
    } else if (!oldWidget.revealed && widget.revealed) {
      _reveal();
    } else if (oldWidget.delay != widget.delay && widget.revealed && !_ready) {
      _reveal();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final body = widget.reduceMotion || _ready
        ? widget.bodyRect
        : widget.baselineRect;
    final cap = widget.reduceMotion || _ready
        ? widget.capOffset
        : widget.baselineCapOffset;
    final motion = motionFor(context, beuiSpringLayout, isMovement: true);
    final color = beuiChartColor(widget.color, colors);
    final bodyMark = Transform.translate(
      offset: body.topLeft,
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scaleX: widget.vertical ? 1 : body.width,
        scaleY: widget.vertical ? body.height : 1,
        child: SizedBox(
          width: widget.vertical ? widget.thickness : 1,
          height: widget.vertical ? 1 : widget.thickness,
          child: ColoredBox(color: color),
        ),
      ),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      curve: beuiEaseOut,
      opacity: widget.opacity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.reduceMotion)
            bodyMark
          else
            MotionBuilder<Rect>(
              value: body,
              motion: motion,
              converter: const RectMotionConverter(),
              builder: (context, rect, _) => Transform.translate(
                offset: rect.topLeft,
                child: Transform.scale(
                  alignment: Alignment.topLeft,
                  scaleX: widget.vertical ? 1 : rect.width,
                  scaleY: widget.vertical ? rect.height : 1,
                  child: SizedBox(
                    width: widget.vertical ? widget.thickness : 1,
                    height: widget.vertical ? 1 : widget.thickness,
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
          if (widget.radius > 0)
            if (widget.reduceMotion)
              Transform.translate(
                offset: cap,
                child: SizedBox(
                  width: widget.vertical ? widget.thickness : widget.radius * 2,
                  height: widget.vertical
                      ? widget.radius * 2
                      : widget.thickness,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(widget.radius),
                    ),
                  ),
                ),
              )
            else
              MotionBuilder<Offset>(
                value: cap,
                motion: motion,
                converter: const OffsetMotionConverter(),
                builder: (context, offset, child) =>
                    Transform.translate(offset: offset, child: child),
                child: SizedBox(
                  width: widget.vertical ? widget.thickness : widget.radius * 2,
                  height: widget.vertical
                      ? widget.radius * 2
                      : widget.thickness,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(widget.radius),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Legend that hides rows and highlights their bars on hover/focus.
class BeuiBarChartLegend extends StatelessWidget {
  const BeuiBarChartLegend({super.key});
  @override
  Widget build(BuildContext context) {
    final model = BeuiBarChart.of(context);
    return BeuiXYLegend(
      rows: model.rows,
      hidden: model.hiddenSeries,
      onToggle: model.onToggleSeries,
      onHover: model.onHoverSeries,
      canHover: model.canHover,
      label: 'Series',
    );
  }
}

/// Tooltip anchored to the end of the longest bar, with pointer-follow behavior.
class BeuiBarChartTooltip extends StatelessWidget {
  const BeuiBarChartTooltip({
    super.key,
    this.child,
    this.builder,
    this.side = BeuiTooltipSide.top,
  });

  /// Static custom tooltip content, matching the source's static child slot.
  final Widget? child;

  /// Renders category-specific content and takes precedence over [child].
  final Widget Function(BeuiBarChartTooltipData data)? builder;
  final BeuiTooltipSide side;
  @override
  Widget build(BuildContext context) {
    final model = BeuiBarChart.of(context);
    final index = model.activeIndex;
    if (index < 0 || index >= model.categories.length) {
      return const SizedBox.shrink();
    }
    final category = model.categories[index];
    final rows = [
      for (final row in model.visibleRows)
        BeuiXYTooltipRow(
          id: row.id,
          name: row.name,
          color: row.color,
          value: row.values[index],
        ),
    ];
    final total = model.totals[index];
    final customData = BeuiBarChartTooltipData(
      category: category,
      index: index,
      rows: List.unmodifiable(rows),
      total: total,
    );
    final content =
        builder?.call(customData) ??
        child ??
        BeuiXYTooltipContent(
          title: category,
          rows: rows,
          formatValue: model.formatValue,
          total: model.layout == BeuiBarChartLayout.stacked && rows.length > 1
              ? total
              : null,
          compact: true,
        );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final surfaceMaxWidth = math.min(256.0, math.max(0.0, viewportWidth - 16));
    final contentMaxWidth = math.max(0.0, surfaceMaxWidth - 22);
    return BeuiTooltip(
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        child: content,
      ),
      side: side,
      sideOffset: model.pointerPosition == null ? 8 : 12,
      open: model.open,
      onOpenChange: model.onOpen,
      externalAnchor: model.tooltipAnchor,
      anchorLink: model.tooltipAnchorLink,
      child: const SizedBox.shrink(),
    );
  }
}
