/// Responsive, inspectable XY line and area charts.
library;

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../motion/_engine.dart'
    show CurvedMotion, SingleMotionController, SpringMotion;
import '../motion/tooltip.dart'
    show BeuiTooltip, BeuiTooltipAlign, BeuiTooltipSide;
import '../motion/text_shimmer.dart' show BeuiTextShimmer;
import '../theme/beui_colors.dart';
import '../tokens/motion.dart'
    show beuiEaseInOut, beuiEaseOut, beuiSpringLayout;
import '../motion/_scroll_geometry.dart';
import '_shared.dart';
import '_xy.dart';
import '_xy_parts.dart';

// why: the tooltip trails the inspected sample more softly than mark geometry.
const _lineTooltipFollow = SpringMotion(
  SpringDescription(mass: .7, stiffness: 260, damping: 28),
);
// why: the category label rolls independently of the pill's layout spring.
const _linePillSwap = SpringMotion(
  SpringDescription(mass: .55, stiffness: 460, damping: 30),
);
const _baselinePointKey = 'line-baseline';

({BeuiTooltipSide side, Offset origin, Offset anchor}) _lineTooltipPlacement({
  required BeuiLineChartTooltipSide preferred,
  required Size chartSize,
  required Size panelSize,
  required int index,
  required int count,
  required num highestValue,
  required BeuiXYDomain domain,
}) {
  const axis = 44.0;
  const right = 16.0;
  const top = 12.0;
  const bottom = 8.0;
  const gap = 16.0;
  const bleedLeft = 40.0;
  const bleedRight = 12.0;
  final plotWidth = math.max(0.0, chartSize.width - axis - right);
  final plotHeight = math.max(0.0, chartSize.height - top - bottom);
  final px = count == 1 ? plotWidth / 2 : index / (count - 1) * plotWidth;
  final py = (1 - domain.fraction(highestValue)) * plotHeight;
  final maxX = plotWidth + bleedRight;
  final minX = -bleedLeft;
  final fitsRight = px + gap + panelSize.width <= maxX;
  final fitsLeft = px - gap - panelSize.width >= minX;
  final side = switch (preferred) {
    BeuiLineChartTooltipSide.right => BeuiTooltipSide.right,
    BeuiLineChartTooltipSide.left => BeuiTooltipSide.left,
    BeuiLineChartTooltipSide.auto when fitsRight => BeuiTooltipSide.right,
    BeuiLineChartTooltipSide.auto when fitsLeft => BeuiTooltipSide.left,
    BeuiLineChartTooltipSide.auto when py - gap - panelSize.height >= 0 =>
      BeuiTooltipSide.top,
    BeuiLineChartTooltipSide.auto => BeuiTooltipSide.bottom,
  };
  double clampX(double value) =>
      math.min(math.max(value, minX), maxX - panelSize.width);
  double clampY(double value) => math
      .min(math.max(value, -8), math.max(-8, plotHeight + 8 - panelSize.height))
      .toDouble();
  final local = switch (side) {
    BeuiTooltipSide.right => Offset(
      px + gap,
      clampY(py - panelSize.height / 2),
    ),
    BeuiTooltipSide.left => Offset(
      px - gap - panelSize.width,
      clampY(py - panelSize.height / 2),
    ),
    BeuiTooltipSide.top => Offset(
      clampX(px - panelSize.width / 2),
      py - gap - panelSize.height,
    ),
    BeuiTooltipSide.bottom => Offset(
      clampX(px - panelSize.width / 2),
      py + gap,
    ),
  };
  final origin = Offset(axis + local.dx, top + local.dy);
  final anchor = switch (side) {
    BeuiTooltipSide.top => Offset(
      origin.dx + panelSize.width / 2,
      origin.dy + panelSize.height + gap,
    ),
    BeuiTooltipSide.bottom => Offset(
      origin.dx + panelSize.width / 2,
      origin.dy - gap,
    ),
    BeuiTooltipSide.left => Offset(
      origin.dx + panelSize.width + gap,
      origin.dy + panelSize.height / 2,
    ),
    BeuiTooltipSide.right => Offset(
      origin.dx - gap,
      origin.dy + panelSize.height / 2,
    ),
  };
  return (side: side, origin: origin, anchor: anchor);
}

/// A chart with unbroken strokes between valid samples.
enum BeuiLineChartVariant {
  /// Draw strokes only.
  line,

  /// Fill each contiguous series run toward zero.
  area,
}

/// Tooltip placement relative to the inspected sample.
enum BeuiLineChartTooltipSide {
  /// Choose the side with the most room.
  auto,

  /// Place to the left of the sample.
  left,

  /// Place to the right of the sample.
  right,
}

/// Public XY series type used by [BeuiLineChart].
typedef BeuiLineChartSeries = BeuiXYSeries;

/// Public interpolation type used by [BeuiLineChart].
typedef BeuiLineChartCurve = BeuiXYCurve;

/// Values passed to a custom [BeuiLineChartTooltip] renderer.
@immutable
class BeuiLineChartTooltipData {
  /// Creates a tooltip snapshot for one inspected category.
  const BeuiLineChartTooltipData({
    required this.category,
    required this.index,
    required this.rows,
  });

  /// Category label.
  final String category;

  /// Category position in the normalized chart.
  final int index;

  /// Every visible series, including rows with a gap at this category.
  final List<BeuiXYTooltipRow> rows;
}

/// Line chart state available to custom compositions and its public parts.
@immutable
class BeuiLineChartModel {
  const BeuiLineChartModel._({
    required this.rows,
    required this.categories,
    required this.visibleRows,
    required this.hiddenSeries,
    required this.activeId,
    required this.activeIndex,
    required this.open,
    required this.touching,
    required this.variant,
    required this.curve,
    required this.domain,
    required this.label,
    required this.loading,
    required this.loadingLabel,
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
    required this.tooltipAnchorPosition,
    required this.onTooltipAnchorPosition,
    required this.plotSize,
    required this.onPlotSize,
  });

  /// All normalized source rows, including hidden series.
  final List<BeuiXYRow> rows;

  /// Unique category labels in source order.
  final List<String> categories;

  /// Rows currently visible in the plot and tooltip.
  final List<BeuiXYRow> visibleRows;

  /// Hidden series IDs.
  final List<String> hiddenSeries;

  /// Inspected category ID, or null when none is selected.
  final String? activeId;

  /// Inspected normalized category position, or -1.
  final int activeIndex;

  /// Whether the shared inspector readout is open.
  final bool open;

  /// Whether a touch pointer is currently dragging.
  final bool touching;

  /// Stroke-only or area fill variant.
  final BeuiLineChartVariant variant;

  /// Path interpolation mode.
  final BeuiLineChartCurve curve;

  /// Current visible-series value domain.
  final BeuiXYDomain domain;

  /// Accessible chart name.
  final String label;

  /// Loading state.
  final bool loading;

  /// Loading placeholder text.
  final String loadingLabel;

  /// Value formatter.
  final String Function(num value) formatValue;

  /// Value-axis tick formatter.
  final String Function(num value) formatTick;

  /// Hovered or keyboard-focused legend series, if any.
  final String? highlightedSeries;

  /// Whether hover inspection is supported.
  final bool canHover;

  /// Requests an inspected category by ID.
  final ValueChanged<String?> onActive;

  /// Controls tooltip visibility.
  final ValueChanged<bool> onOpen;

  /// Reports touch drag state.
  final ValueChanged<bool> onTouch;

  /// Toggles a legend series.
  final ValueChanged<String> onToggleSeries;

  /// Highlights a legend series while hovered/focused.
  final ValueChanged<String?> onHoverSeries;

  final GlobalKey tooltipAnchor;
  final LayerLink tooltipAnchorLink;
  final Offset tooltipAnchorPosition;
  final ValueChanged<Offset> onTooltipAnchorPosition;
  final Size plotSize;
  final ValueChanged<Size> onPlotSize;
}

/// Composable line/area chart. Omit [child] for plot, tooltip and legend.
class BeuiLineChart extends StatefulWidget {
  /// Reads the nearest chart model for custom compositions.
  static BeuiLineChartModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_LineChartScope>();
    if (scope == null) {
      throw FlutterError(
        'Line chart parts must be rendered inside BeuiLineChart.',
      );
    }
    return scope.model;
  }

  /// Creates a line or area chart.
  const BeuiLineChart({
    required this.series,
    required this.categories,
    super.key,
    this.variant = BeuiLineChartVariant.line,
    this.curve = BeuiLineChartCurve.monotone,
    this.domain,
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
    this.label = 'Line chart',
    this.status = BeuiLineChartStatus.ready,
    this.loadingLabel = 'Loading data',
    this.child,
  });

  /// Series whose sample values align with [categories] by index.
  final List<BeuiLineChartSeries> series;

  /// Unique x-axis labels in display order.
  final List<String> categories;

  /// Stroke-only or zero-baseline filled presentation.
  final BeuiLineChartVariant variant;

  /// Interpolation for each contiguous path run.
  final BeuiLineChartCurve curve;

  /// Optional finite, ascending value bounds. Otherwise visible values set it.
  final (num, num)? domain;

  /// Controlled category ID. Pass [controlledActive] to control an explicit null.
  final String? activeId;

  /// Initial inspected category for uncontrolled use.
  final String? defaultActiveId;

  /// Called when the inspected category changes.
  final ValueChanged<String?>? onActiveChange;

  /// Treat [activeId] as controlled, including when it is null.
  final bool controlledActive;

  /// Controlled set of hidden series IDs.
  final List<String>? hiddenSeries;

  /// Initial hidden IDs for uncontrolled use.
  final List<String> defaultHiddenSeries;

  /// Called with the complete immutable hidden ID set.
  final ValueChanged<List<String>>? onHiddenSeriesChange;

  /// Treat [hiddenSeries] as controlled, including when it is empty.
  final bool controlledHiddenSeries;

  /// Tooltip formatter. Defaults to en-style grouping with at most two decimals.
  final String Function(num value)? formatValue;

  /// Tick formatter. Defaults to compact notation with one decimal.
  final String Function(num value)? formatTick;

  /// Accessible name for the chart and inspection control.
  final String label;

  /// Ready chart or loading placeholder.
  final BeuiLineChartStatus status;

  /// Placeholder label. An empty value leaves only a screen-reader loading label.
  final String loadingLabel;

  /// Custom composition; defaults to plot + tooltip + multi-series legend.
  final Widget? child;

  @override
  State<BeuiLineChart> createState() => _BeuiLineChartState();
}

/// Data availability for [BeuiLineChart].
enum BeuiLineChartStatus {
  /// Render normalized data.
  ready,

  /// Hide marks and inspection while showing a loading placeholder.
  loading,
}

class _BeuiLineChartState extends State<BeuiLineChart> {
  String? _internalActive;
  late List<String> _internalHidden;
  bool _open = false;
  bool _touching = false;
  String? _hoveredSeries;
  String? _focusedSeries;
  final GlobalKey _tooltipAnchor = GlobalKey(
    debugLabel: 'line-chart-tooltip-anchor',
  );
  final LayerLink _tooltipAnchorLink = LayerLink();
  Offset _tooltipAnchorPosition = Offset.zero;
  Size _plotSize = Size.zero;

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
  void didUpdateWidget(covariant BeuiLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activeControlled &&
        _internalActive != null &&
        !widget.categories.contains(_internalActive)) {
      _internalActive = null;
      _open = false;
    }
    final rowIds = widget.series.map((row) => row.id).toSet();
    if (_hoveredSeries != null && !rowIds.contains(_hoveredSeries)) {
      _hoveredSeries = null;
    }
    if (_focusedSeries != null && !rowIds.contains(_focusedSeries)) {
      _focusedSeries = null;
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

  void _setOpen(bool value) {
    if (_open != value) setState(() => _open = value);
  }

  void _setTouching(bool value) {
    if (_touching != value) setState(() => _touching = value);
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
    final data = normalizeBeuiXY(widget.series, widget.categories);
    final hidden = _requestedHidden;
    final visible = data.rows.where((row) => !hidden.contains(row.id)).toList();
    final values = visible
        .expand((row) => row.values.whereType<num>())
        .where((value) => value.toDouble().isFinite)
        .toList();
    final resolvedDomain = niceBeuiXYDomain(
      values,
      includeZero: widget.variant == BeuiLineChartVariant.area,
      fixed: widget.domain,
    );
    final requested = _requestedActive;
    final active = requested != null && data.categories.contains(requested)
        ? requested
        : null;
    final activeIndex = active == null ? -1 : data.categories.indexOf(active);
    final loading = widget.status == BeuiLineChartStatus.loading;
    final model = BeuiLineChartModel._(
      rows: data.rows,
      categories: data.categories,
      visibleRows: List.unmodifiable(visible),
      hiddenSeries: List.unmodifiable(hidden),
      activeId: active,
      activeIndex: activeIndex,
      open: _open && !loading && activeIndex >= 0,
      touching: _touching,
      variant: widget.variant,
      curve: widget.curve,
      domain: resolvedDomain,
      label: widget.label,
      loading: loading,
      loadingLabel: widget.loadingLabel,
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
      highlightedSeries:
          visible.any((row) => row.id == (_hoveredSeries ?? _focusedSeries))
          ? _hoveredSeries ?? _focusedSeries
          : null,
      canHover: true,
      onActive: (id) => _setActive(id, data.categories),
      onOpen: _setOpen,
      onTouch: _setTouching,
      onToggleSeries: _toggleHidden,
      onHoverSeries: (id) => setState(() => _hoveredSeries = id),
      tooltipAnchor: _tooltipAnchor,
      tooltipAnchorLink: _tooltipAnchorLink,
      tooltipAnchorPosition: _tooltipAnchorPosition,
      onTooltipAnchorPosition: (position) {
        if (_tooltipAnchorPosition == position) return;
        setState(() => _tooltipAnchorPosition = position);
      },
      plotSize: _plotSize,
      onPlotSize: (size) {
        if (_plotSize != size) setState(() => _plotSize = size);
      },
    );
    return _LineChartScope(
      model: model,
      child: Semantics(
        container: true,
        label: widget.label,
        liveRegion: loading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.child != null)
              widget.child!
            else ...[
              const BeuiLineChartPlot(),
              const BeuiLineChartTooltip(),
              if (data.rows.length > 1) const BeuiLineChartLegend(),
            ],
            if (!loading)
              BeuiXYDataTable(
                label: model.label,
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

class _LineChartScope extends InheritedWidget {
  const _LineChartScope({required this.model, required super.child});
  final BeuiLineChartModel model;
  @override
  bool updateShouldNotify(_LineChartScope oldWidget) =>
      model != oldWidget.model;
}

/// Main responsive plot with shared point tracking and keyboard inspection.
class BeuiLineChartPlot extends StatefulWidget {
  /// Creates the plot.
  const BeuiLineChartPlot({
    super.key,
    this.height = 288,
    this.strokeWidth = 2,
    this.showGrid = true,
    this.fadeEdges = true,
  });

  /// Plot height excluding category labels.
  final double height;

  /// Series stroke width.
  final double strokeWidth;

  /// Draw horizontal value grid lines.
  final bool showGrid;

  /// Fade strokes and fills at both plot edges.
  final bool fadeEdges;

  @override
  State<BeuiLineChartPlot> createState() => _BeuiLineChartPlotState();
}

class _BeuiLineChartPlotState extends State<BeuiLineChartPlot>
    with ScrollGeometryMixin<BeuiLineChartPlot> {
  final GlobalKey _plotBoundsKey = GlobalKey(
    debugLabel: 'line-chart-in-view-plot',
  );
  bool _entered = false;

  @override
  void onScrollGeometryChanged() {
    _measureViewportFallback();
  }

  void _measureViewportFallback() {
    if (_entered || !mounted) return;
    final box = _plotBoundsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.height <= 0) return;
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject() as RenderBox?;
    final inViewport = viewport != null && viewport.hasSize;
    final top = inViewport
        ? box.localToGlobal(Offset.zero, ancestor: viewport).dy
        : box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewportHeight = inViewport
        ? viewport.size.height
        : MediaQuery.sizeOf(context).height;
    final visible =
        (bottom.clamp(0.0, viewportHeight) - top.clamp(0.0, viewportHeight)) /
        box.size.height;
    if (visible >= .3) setState(() => _entered = true);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureViewportFallback();
      onScrollGeometryChanged();
    });
    final model = BeuiLineChart.of(context);
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    const axis = 44.0;
    const right = 16.0;
    const top = 12.0;
    const bottom = 8.0;
    const labelsTop = 2.0;
    const labelsGap = 8.0;
    const labelsHeight = 20.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = model.categories.length;
        if (!model.loading && (count == 0 || model.rows.isEmpty)) {
          return SizedBox(
            height: widget.height,
            child: Center(
              child: Text(
                'No data',
                style: TextStyle(fontSize: 14, color: colors.mutedForeground),
              ),
            ),
          );
        }
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 640.0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) model.onPlotSize(Size(width, widget.height));
        });
        final plotWidth = math.max(0.0, width - axis - right);
        final innerHeight = math.max(0.0, widget.height - top - bottom);
        final edgeFade = plotWidth <= 0
            ? 0.0
            : math.min(32.0, plotWidth * .08) / plotWidth;
        double x(int index) =>
            axis +
            (count <= 1 ? plotWidth / 2 : index / (count - 1) * plotWidth);
        double y(num value) =>
            top + (1 - model.domain.fraction(value)) * innerHeight;
        final baseline = y(
          math.min(model.domain.max, math.max(model.domain.min, 0)),
        );
        final categoryLabelStyle = TextStyle(
          fontSize: 11,
          color: colors.mutedForeground,
        );
        final categoryTextStyle = DefaultTextStyle.of(
          context,
        ).style.merge(categoryLabelStyle);
        final categoryTextScaler = MediaQuery.textScalerOf(context);
        double categoryLabelWidth(int index) => (TextPainter(
          text: TextSpan(
            text: model.categories[index],
            style: categoryTextStyle,
          ),
          textDirection: Directionality.of(context),
          textScaler: categoryTextScaler,
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
        )..layout()).width;
        final targets = <BeuiXYPointTarget>[
          BeuiXYPointTarget(
            key: _baselinePointKey,
            position: Offset(0, baseline),
          ),
          for (final row in model.rows)
            for (var i = 0; i < row.values.length; i++)
              if (row.values[i] != null)
                BeuiXYPointTarget(
                  key: _pointKey(row.id, model.categories[i]),
                  position: Offset(x(i), y(row.values[i]!)),
                ),
        ];
        final active = model.activeIndex >= 0 && !model.loading
            ? model.activeIndex
            : null;
        final stride = beuiXYLabelStride(count, plotWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: _plotBoundsKey,
              height: widget.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: BeuiXYAxisLayer(
                      key: const ValueKey('line-axis-grid'),
                      ticks: model.domain.ticks,
                      position: y,
                      axis: Axis.vertical,
                      from: axis,
                      to: axis + plotWidth,
                      labelOffset: axis,
                      format: model.formatTick,
                      showGrid: widget.showGrid,
                      showLabels: false,
                      reduceMotion: reduce,
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: model.loading ? 0 : 1,
                      duration: const Duration(milliseconds: 150),
                      curve: beuiEaseOut,
                      child: BeuiXYAxisLayer(
                        key: const ValueKey('line-axis-labels'),
                        ticks: model.domain.ticks,
                        position: y,
                        axis: Axis.vertical,
                        from: axis,
                        to: axis + plotWidth,
                        labelOffset: axis,
                        format: model.formatTick,
                        showGrid: false,
                        showLabels: true,
                        reduceMotion: reduce,
                      ),
                    ),
                  ),
                  if (!model.loading && (count == 0 || model.rows.isEmpty))
                    Positioned.fill(
                      left: axis,
                      right: right,
                      child: Center(
                        child: Text(
                          'No data',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    )
                  else if (plotWidth > 0 && model.rows.isNotEmpty)
                    Positioned.fill(
                      child: BeuiXYPointTracker(
                        targets: targets,
                        width: width,
                        reduceMotion: reduce,
                        builder: (points) {
                          final dataLayer = Stack(
                            fit: StackFit.expand,
                            children: [
                              for (final row in model.rows)
                                AnimatedOpacity(
                                  key: ValueKey(
                                    'line-series-opacity-${row.id}',
                                  ),
                                  opacity: model.hiddenSeries.contains(row.id)
                                      ? 0
                                      : model.highlightedSeries != null &&
                                            model.highlightedSeries != row.id
                                      ? .2
                                      : 1,
                                  duration: const Duration(milliseconds: 180),
                                  curve: beuiEaseOut,
                                  child: CustomPaint(
                                    painter: _LineChartPainter(
                                      rows: [row],
                                      seriesCount: model.rows.length,
                                      points: points,
                                      categories: model.categories,
                                      curve: model.curve,
                                      variant: model.variant,
                                      baseline:
                                          points[_baselinePointKey]?.dy ??
                                          baseline,
                                      strokeWidth: widget.strokeWidth,
                                      colors: colors,
                                    ),
                                  ),
                                ),
                            ],
                          );
                          final reveal = _LineChartReveal(
                            loading: model.loading,
                            entered: _entered,
                            reduceMotion: reduce,
                            width: width,
                            height: widget.height,
                            child: AnimatedOpacity(
                              key: const ValueKey('line-series-loading-fade'),
                              opacity: model.loading ? 0 : 1,
                              duration: const Duration(milliseconds: 150),
                              curve: beuiEaseOut,
                              child: dataLayer,
                            ),
                          );
                          final rightFade = _LineChartRightFade(
                            width: width,
                            crossX: active == null ? axis : x(active),
                            active: model.open && active != null,
                            snap: model.touching || reduce,
                            child: reveal,
                          );
                          final maskedReveal = widget.fadeEdges
                              ? ShaderMask(
                                  blendMode: BlendMode.dstIn,
                                  shaderCallback: (rect) =>
                                      LinearGradient(
                                        colors: const [
                                          Colors.transparent,
                                          Colors.white,
                                          Colors.white,
                                          Colors.transparent,
                                        ],
                                        stops: [0, edgeFade, 1 - edgeFade, 1],
                                      ).createShader(
                                        Rect.fromLTWH(
                                          axis,
                                          rect.top,
                                          plotWidth,
                                          rect.height,
                                        ),
                                      ),
                                  child: rightFade,
                                )
                              : rightFade;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(child: maskedReveal),
                              if (active != null && model.open)
                                for (final row in model.visibleRows)
                                  if (row.values[active] != null &&
                                      points[_pointKey(
                                            row.id,
                                            model.categories[active],
                                          )] !=
                                          null)
                                    _LineChartInspectionMark(
                                      key: ValueKey('mark-${row.id}'),
                                      position: Offset(
                                        x(active),
                                        y(row.values[active]!),
                                      ),
                                      color: beuiChartColor(row.color, colors),
                                      snap: model.touching || reduce,
                                      background: colors.background,
                                    ),
                            ],
                          );
                        },
                      ),
                    ),
                  Positioned.fill(
                    left: axis,
                    right: right,
                    top: top,
                    bottom: bottom,
                    child: IgnorePointer(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => LinearGradient(
                          colors: widget.fadeEdges
                              ? const [
                                  Colors.transparent,
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ]
                              : const [Colors.white, Colors.white],
                          stops: widget.fadeEdges
                              ? [0, edgeFade, 1 - edgeFade, 1]
                              : null,
                        ).createShader(rect),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          reverseDuration: const Duration(milliseconds: 120),
                          switchInCurve: beuiEaseOut,
                          switchOutCurve: beuiEaseOut,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: model.loading
                              ? _LineChartLoading(
                                  key: const ValueKey('line-loading'),
                                  reduceMotion: reduce,
                                  color: colors.mutedForeground,
                                  strokeWidth: widget.strokeWidth,
                                )
                              : const SizedBox.expand(
                                  key: ValueKey('line-ready'),
                                ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    left: axis,
                    right: right,
                    top: top,
                    bottom: bottom,
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        reverseDuration: const Duration(milliseconds: 180),
                        switchInCurve: beuiEaseOut,
                        switchOutCurve: beuiEaseOut,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: AnimatedBuilder(
                            animation: animation,
                            child: child,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                0,
                                !reduce &&
                                        animation.status ==
                                            AnimationStatus.reverse
                                    ? (1 - animation.value) * 8
                                    : 0,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                        child: model.loading
                            ? Semantics(
                                key: const ValueKey('line-loading-label'),
                                liveRegion: true,
                                label: model.loadingLabel.isEmpty
                                    ? 'Loading'
                                    : model.loadingLabel,
                                child: model.loadingLabel.isEmpty
                                    ? const SizedBox.shrink()
                                    : BeuiTextShimmer(
                                        model.loadingLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.mutedForeground,
                                        ),
                                      ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('line-no-loading-label'),
                              ),
                      ),
                    ),
                  ),
                  if (active != null && model.open && plotWidth > 0)
                    Positioned(
                      left: 0,
                      top: top,
                      bottom: bottom,
                      child: _LineChartSpringX(
                        value: x(active),
                        snap: model.touching || reduce,
                        child: _LineChartEntranceFade(
                          child: IgnorePointer(
                            child: Container(
                              width: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colors.foreground.withValues(alpha: 0),
                                    colors.foreground.withValues(alpha: .35),
                                    colors.foreground.withValues(alpha: .35),
                                    colors.foreground.withValues(alpha: 0),
                                  ],
                                  stops: const [0, .25, .75, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!model.loading && count > 0)
                    Positioned.fill(
                      key: const ValueKey('line-inspector-position'),
                      left: axis,
                      right: right,
                      top: top,
                      bottom: bottom,
                      child: BeuiXYFocusOutline(
                        child: BeuiXYInspector(
                          count: count,
                          activeIndex: model.activeIndex,
                          onActiveIndexChanged: (index) =>
                              model.onActive(model.categories[index]),
                          label: '${model.label}: inspect values',
                          valueText: (index) => [
                            model.categories[index],
                            for (final row in model.visibleRows)
                              '${row.name} ${row.values[index] == null ? 'no data' : model.formatValue(row.values[index]!)}',
                          ].join('. '),
                          open: model.open,
                          onOpenChange: model.onOpen,
                          onTouchChange: model.onTouch,
                          canHover: model.canHover,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  if (active != null && model.open && plotWidth > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _LineChartFollowAnchor(
                        position: model.tooltipAnchorPosition,
                        snap: model.touching || reduce,
                        child: CompositedTransformTarget(
                          key: model.tooltipAnchor,
                          link: model.tooltipAnchorLink,
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: labelsGap),
            SizedBox(
              height: labelsHeight,
              child: AnimatedOpacity(
                key: const ValueKey('line-category-loading-fade'),
                opacity: model.loading ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                curve: beuiEaseOut,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < count; i++)
                      if ((count - 1 - i) % stride == 0)
                        Positioned(
                          left: x(i),
                          top: labelsTop,
                          child: FractionalTranslation(
                            translation: const Offset(-.5, 0),
                            child: SizedBox(
                              key: ValueKey('line-category-label-$i'),
                              width: categoryLabelWidth(i),
                              child: AnimatedOpacity(
                                opacity:
                                    active != null &&
                                        (x(i) - x(active)).abs() < 40
                                    ? 0
                                    : 1,
                                duration: const Duration(milliseconds: 150),
                                curve: beuiEaseOut,
                                child: Text(
                                  model.categories[i],
                                  softWrap: false,
                                  style: categoryLabelStyle,
                                ),
                              ),
                            ),
                          ),
                        ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 100),
                        switchInCurve: beuiEaseOut,
                        switchOutCurve: beuiEaseOut,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: active != null && model.open
                            ? KeyedSubtree(
                                key: const ValueKey('line-category-pill'),
                                child: _LineChartSpringX(
                                  value: x(active),
                                  snap: model.touching || reduce,
                                  child: _LineChartEntranceFade(
                                    child: IgnorePointer(
                                      child: FractionalTranslation(
                                        translation: const Offset(-.5, 0),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: colors.foreground,
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            child: ClipRect(
                                              child: _LineChartPillLabel(
                                                category:
                                                    model.categories[active],
                                                index: active,
                                                reduceMotion: reduce,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: colors.background,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('line-no-category-pill'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LineChartReveal extends StatefulWidget {
  const _LineChartReveal({
    required this.loading,
    required this.entered,
    required this.reduceMotion,
    required this.width,
    required this.height,
    required this.child,
  });

  final bool loading;
  final bool entered;
  final bool reduceMotion;
  final double width;
  final double height;
  final Widget child;

  @override
  State<_LineChartReveal> createState() => _LineChartRevealState();
}

class _LineChartRevealState extends State<_LineChartReveal>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _progress = SingleMotionController(
    motion: CurvedMotion(const Duration(milliseconds: 700), beuiEaseOut),
    vsync: this,
    initialValue: 0,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _LineChartReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading ||
        oldWidget.entered != widget.entered ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      _sync();
    }
  }

  void _sync() {
    _delay?.cancel();
    _progress.stop(canceled: true);
    if (widget.reduceMotion) {
      _progress.value = 1;
    } else if (widget.loading) {
      if (_progress.value > 0) {
        _delay = Timer(const Duration(milliseconds: 160), () {
          if (mounted && widget.loading) _progress.value = 0;
        });
      }
    } else if (widget.entered && _progress.value < 1) {
      _delay = Timer(const Duration(milliseconds: 120), () {
        if (mounted && !widget.loading && widget.entered) {
          _progress.animateTo(1);
        }
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) => SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRect(
        clipper: _LineChartRevealClipper(_progress.value),
        child: child,
      ),
    ),
  );
}

class _LineChartRevealClipper extends CustomClipper<Rect> {
  const _LineChartRevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    0,
    size.width * progress.clamp(0.0, 1.0).toDouble(),
    size.height,
  );

  @override
  bool shouldReclip(_LineChartRevealClipper oldClipper) =>
      progress != oldClipper.progress;
}

class _LineChartSpringX extends StatelessWidget {
  const _LineChartSpringX({
    required this.value,
    required this.snap,
    required this.child,
  });

  final double value;
  final bool snap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (snap) {
      return Transform.translate(offset: Offset(value, 0), child: child);
    }
    return BeuiChartSpring(
      value: value,
      builder: (context, x) =>
          Transform.translate(offset: Offset(x, 0), child: child),
    );
  }
}

class _LineChartEntranceFade extends StatefulWidget {
  const _LineChartEntranceFade({required this.child});

  final Widget child;

  @override
  State<_LineChartEntranceFade> createState() => _LineChartEntranceFadeState();
}

class _LineChartEntranceFadeState extends State<_LineChartEntranceFade>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _opacity = SingleMotionController(
    motion: CurvedMotion(const Duration(milliseconds: 120), beuiEaseOut),
    vsync: this,
    initialValue: 0,
  );

  @override
  void initState() {
    super.initState();
    _opacity.animateTo(1);
  }

  @override
  void dispose() {
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _opacity,
    child: widget.child,
    builder: (context, child) => Opacity(opacity: _opacity.value, child: child),
  );
}

class _LineChartRightFade extends StatelessWidget {
  const _LineChartRightFade({
    required this.width,
    required this.crossX,
    required this.active,
    required this.snap,
    required this.child,
  });

  final double width;
  final double crossX;
  final bool active;
  final bool snap;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: active ? .6 : 0),
    duration: const Duration(milliseconds: 180),
    curve: beuiEaseOut,
    child: child,
    builder: (context, intensity, child) {
      Widget maskAt(double x) {
        final stop = width <= 0 ? 0.0 : (x / width).clamp(0.0, 1.0);
        final opacity = (1 - intensity).clamp(0.0, 1.0);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            colors: [
              Colors.white,
              Colors.white,
              Colors.white.withValues(alpha: opacity),
            ],
            stops: [0, stop, stop],
          ).createShader(rect),
          child: child,
        );
      }

      if (snap || !active) return maskAt(active ? crossX : 0);
      return BeuiChartSpring(value: crossX, builder: (context, x) => maskAt(x));
    },
  );
}

class _LineChartInspectionMark extends StatefulWidget {
  const _LineChartInspectionMark({
    required this.position,
    required this.color,
    required this.snap,
    required this.background,
    super.key,
  });

  final Offset position;
  final Color color;
  final bool snap;
  final Color background;

  @override
  State<_LineChartInspectionMark> createState() =>
      _LineChartInspectionMarkState();
}

class _LineChartInspectionMarkState extends State<_LineChartInspectionMark>
    with TickerProviderStateMixin {
  late final SingleMotionController _scale = SingleMotionController(
    motion: beuiSpringLayout,
    vsync: this,
    initialValue: widget.snap ? 1 : .5,
  );
  late final SingleMotionController _opacity = SingleMotionController(
    motion: CurvedMotion(const Duration(milliseconds: 120), beuiEaseOut),
    vsync: this,
    initialValue: 0,
  )..animateTo(1);

  @override
  void initState() {
    super.initState();
    if (!widget.snap) _scale.animateTo(1);
  }

  @override
  void didUpdateWidget(covariant _LineChartInspectionMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snap) {
      _scale.stop();
      _scale.value = 1;
    } else if (oldWidget.snap) {
      _scale.value = 1;
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = Rect.fromCenter(
      center: widget.position,
      width: 20,
      height: 20,
    );
    final dot = Stack(
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: .18),
            shape: BoxShape.circle,
          ),
          child: const SizedBox.expand(),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(color: widget.background, width: 2),
          ),
        ),
      ],
    );
    final marker = AnimatedBuilder(
      animation: Listenable.merge([_scale, _opacity]),
      child: dot,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
    );
    Positioned at(Rect rect) => Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: marker,
    );

    if (widget.snap) return at(bounds);
    return BeuiChartSpringRect(
      value: bounds,
      builder: (context, rect) => at(rect),
    );
  }
}

class _LineChartPillLabel extends StatefulWidget {
  const _LineChartPillLabel({
    required this.category,
    required this.index,
    required this.reduceMotion,
    required this.style,
  });

  final String category;
  final int index;
  final bool reduceMotion;
  final TextStyle style;

  @override
  State<_LineChartPillLabel> createState() => _LineChartPillLabelState();
}

class _LineChartPillLabelState extends State<_LineChartPillLabel>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _progress = SingleMotionController(
    motion: _linePillSwap,
    vsync: this,
    initialValue: 1,
  );
  int _direction = 1;
  String? _previousCategory;

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener(_onProgressStatus);
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previousCategory != null) {
      setState(() => _previousCategory = null);
    }
  }

  @override
  void didUpdateWidget(covariant _LineChartPillLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      if (oldWidget.index != widget.index) {
        _direction = widget.index < oldWidget.index ? -1 : 1;
        _previousCategory = oldWidget.category;
      }
      _progress.stop(canceled: true);
      _progress.motion = widget.reduceMotion
          ? CurvedMotion(const Duration(milliseconds: 120), beuiEaseOut)
          : _linePillSwap;
      _progress.value = 0;
      _progress.animateTo(1);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, _) {
      final progress = _progress.value.clamp(0.0, 1.0);
      Widget label(String text, double opacity, double offset) => Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, widget.reduceMotion ? 0 : offset),
          child: Text(text, style: widget.style),
        ),
      );

      return Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: [
          if (_previousCategory case final previous?)
            label(previous, 1 - progress, -_direction * 10 * progress),
          label(widget.category, progress, _direction * 10 * (1 - progress)),
        ],
      );
    },
  );
}

/// Shared-tooltip composition for the inspected category.
class BeuiLineChartTooltip extends StatefulWidget {
  /// Creates a chart tooltip.
  const BeuiLineChartTooltip({
    super.key,
    this.builder,
    this.child,
    this.side = BeuiLineChartTooltipSide.auto,
  });

  /// Optional content renderer. Receives category, index, and visible rows.
  final Widget Function(BeuiLineChartTooltipData data)? builder;

  /// Static custom content. [builder] takes precedence when both are provided.
  final Widget? child;

  /// Preferred placement around the point.
  final BeuiLineChartTooltipSide side;

  @override
  State<BeuiLineChartTooltip> createState() => _BeuiLineChartTooltipState();
}

class _BeuiLineChartTooltipState extends State<BeuiLineChartTooltip> {
  final GlobalKey _contentKey = GlobalKey(
    debugLabel: 'line-chart-tooltip-content',
  );
  Size _contentSize = const Size(224, 96);

  void _measureContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || box.size == _contentSize) return;
      setState(() => _contentSize = box.size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = BeuiLineChart.of(context);
    if (model.loading || model.activeIndex < 0 || !model.open) {
      return const SizedBox.shrink();
    }
    final index = model.activeIndex;
    final rows = List<BeuiXYTooltipRow>.unmodifiable([
      for (final row in model.visibleRows)
        BeuiXYTooltipRow(
          id: row.id,
          name: row.name,
          color: row.color,
          value: row.values[index],
        ),
    ]);
    final category = model.categories[index];
    final data = BeuiLineChartTooltipData(
      category: category,
      index: index,
      rows: rows,
    );
    final content =
        widget.builder?.call(data) ??
        widget.child ??
        BeuiXYTooltipContent(
          title: category,
          rows: rows,
          formatValue: model.formatValue,
        );
    _measureContent();
    final values = rows
        .where((row) => row.value != null)
        .map((row) => row.value!);
    final highest = values.isEmpty ? model.domain.max : values.reduce(math.max);
    // The shared tooltip surface adds 22×10px of padding; its border is paint-only.
    final panelSize = Size(_contentSize.width + 22, _contentSize.height + 10);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final maxPanelWidth = math.min(320.0, math.max(0.0, viewportWidth - 32));
    final contentMaxWidth = math.max(0.0, maxPanelWidth - 22);
    final placement = _lineTooltipPlacement(
      preferred: widget.side,
      chartSize: model.plotSize,
      panelSize: panelSize,
      index: index,
      count: model.categories.length,
      highestValue: highest,
      domain: model.domain,
    );
    if (model.tooltipAnchorPosition != placement.anchor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !model.open || model.activeIndex != index) {
          return;
        }
        model.onTooltipAnchorPosition(placement.anchor);
      });
    }
    return BeuiTooltip(
      key: ValueKey('line-tooltip-${model.tooltipAnchor.hashCode}'),
      content: KeyedSubtree(
        key: _contentKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: content,
        ),
      ),
      side: placement.side,
      align: BeuiTooltipAlign.center,
      sideOffset: 16,
      open: true,
      delay: Duration.zero,
      avoidCollisions: false,
      externalAnchor: model.tooltipAnchor,
      anchorLink: model.tooltipAnchorLink,
      child: const SizedBox.shrink(),
    );
  }
}

class _LineChartFollowAnchor extends StatefulWidget {
  const _LineChartFollowAnchor({
    required this.position,
    required this.snap,
    required this.child,
  });

  final Offset position;
  final bool snap;
  final Widget child;

  @override
  State<_LineChartFollowAnchor> createState() => _LineChartFollowAnchorState();
}

class _LineChartFollowAnchorState extends State<_LineChartFollowAnchor>
    with TickerProviderStateMixin {
  late final SingleMotionController _x;
  late final SingleMotionController _y;

  @override
  void initState() {
    super.initState();
    _x = SingleMotionController(
      motion: _lineTooltipFollow,
      vsync: this,
      initialValue: widget.position.dx,
    )..addListener(_changed);
    _y = SingleMotionController(
      motion: _lineTooltipFollow,
      vsync: this,
      initialValue: widget.position.dy,
    )..addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _LineChartFollowAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position == oldWidget.position &&
        widget.snap == oldWidget.snap) {
      return;
    }
    if (widget.snap) {
      _x.stop();
      _y.stop();
      _x.value = widget.position.dx;
      _y.value = widget.position.dy;
    } else {
      _x.animateTo(widget.position.dx);
      _y.animateTo(widget.position.dy);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(_x.value, _y.value),
    child: widget.child,
  );
}

/// Series visibility controls and hover/focus highlighting.
class BeuiLineChartLegend extends StatelessWidget {
  /// Creates a line-chart legend.
  const BeuiLineChartLegend({super.key, this.spacing = 16});

  /// Horizontal gap between items.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final model = BeuiLineChart.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: BeuiXYLegend(
        rows: model.rows,
        hidden: model.hiddenSeries,
        onToggle: model.onToggleSeries,
        onHover: model.onHoverSeries,
        canHover: model.canHover,
        label: 'Series',
        spacing: spacing,
      ),
    );
  }
}

class _LineChartLoading extends StatefulWidget {
  const _LineChartLoading({
    required this.reduceMotion,
    required this.color,
    required this.strokeWidth,
    super.key,
  });
  final bool reduceMotion;
  final Color color;
  final double strokeWidth;

  @override
  State<_LineChartLoading> createState() => _LineChartLoadingState();
}

class _LineChartLoadingState extends State<_LineChartLoading>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _effect =
      SingleMotionController(
          motion: CurvedMotion(
            const Duration(milliseconds: 1600),
            beuiEaseInOut,
          ),
          vsync: this,
          initialValue: 0,
        )
        ..addListener(_effectChanged)
        ..addStatusListener(_effectStatusChanged);
  Timer? _repeatDelay;
  bool _reduce = false;
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant _LineChartLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduce = widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    if (oldWidget.reduceMotion != widget.reduceMotion) _sync();
  }

  void _effectChanged() {
    if (mounted) setState(() {});
  }

  void _effectStatusChanged(AnimationStatus status) {
    if (!_running) return;
    if (status == AnimationStatus.completed && _reduce) {
      _effect.animateTo(0);
    } else if (status == AnimationStatus.dismissed && _reduce) {
      _effect.animateTo(1);
    } else if (status == AnimationStatus.completed) {
      _repeatDelay?.cancel();
      _repeatDelay = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || _reduce) return;
        _effect.value = 0;
        _effect.animateTo(1);
      });
    }
  }

  void _sync() {
    _repeatDelay?.cancel();
    _running = false;
    _effect.stop(canceled: true);
    _effect.motion = CurvedMotion(
      Duration(milliseconds: _reduce ? 900 : 1600),
      beuiEaseInOut,
    );
    _effect.value = 0;
    _running = true;
    _effect.animateTo(1);
  }

  @override
  void dispose() {
    _repeatDelay?.cancel();
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CustomPaint(
        painter: _LoadingLinePainter(
          color: widget.color,
          opacity: _reduce ? .22 + .23 * _effect.value : .22,
          strokeWidth: widget.strokeWidth,
        ),
      ),
      if (!_reduce)
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final band = math.max(80.0, rect.width * .28);
            final left = -band + (rect.width + band) * _effect.value;
            return LinearGradient(
              colors: [Colors.transparent, Colors.white, Colors.transparent],
              stops: const [0, .5, 1],
              begin: Alignment(left / rect.width * 2 - 1, 0),
              end: Alignment((left + band) / rect.width * 2 - 1, 0),
            ).createShader(rect);
          },
          child: CustomPaint(
            painter: _LoadingLinePainter(
              color: widget.color,
              opacity: .75,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
    ],
  );
}

class _LoadingLinePainter extends CustomPainter {
  const _LoadingLinePainter({
    required this.color,
    required this.strokeWidth,
    this.opacity = .22,
  });
  final Color color;
  final double strokeWidth;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final points = <Offset?>[
      for (var i = 0; i < 16; i++)
        Offset(
          size.width * i / 15,
          size.height *
              (.62 - .18 * i / 15 + .07 * math.sin(i / 15 * math.pi * 3)),
        ),
    ];
    canvas.drawPath(
      beuiXYLinePath(points, curve: BeuiXYCurve.monotone),
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LoadingLinePainter oldDelegate) =>
      color != oldDelegate.color ||
      opacity != oldDelegate.opacity ||
      strokeWidth != oldDelegate.strokeWidth;
}

String _pointKey(String series, String category) =>
    '${series.length}:$series${category.length}:$category';

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.rows,
    required this.seriesCount,
    required this.points,
    required this.categories,
    required this.curve,
    required this.variant,
    required this.baseline,
    required this.strokeWidth,
    required this.colors,
  });

  final List<BeuiXYRow> rows;
  final int seriesCount;
  final Map<String, Offset> points;
  final List<String> categories;
  final BeuiXYCurve curve;
  final BeuiLineChartVariant variant;
  final double baseline;
  final double strokeWidth;
  final BeuiColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      44,
      0,
      math.max(44, size.width - 16),
      size.height,
    );
    canvas.save();
    canvas.clipRect(plot);
    for (final row in rows) {
      final pathPoints = List<BeuiXYPathPoint>.generate(row.values.length, (i) {
        if (row.values[i] == null) return null;
        return points[_pointKey(row.id, categories[i])];
      });
      final color = beuiChartColor(row.color, colors);
      const opacity = 1.0; // The row's parent animates source opacity (180ms).
      if (variant == BeuiLineChartVariant.area &&
          pathPoints.any((point) => point != null)) {
        final path = beuiXYAreaPath(pathPoints, baseline, curve: curve);
        final areaBounds = path.getBounds();
        if (!areaBounds.isEmpty) {
          final gradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: seriesCount > 1 ? .14 : .28),
              color.withValues(alpha: 0),
            ],
          ).createShader(areaBounds);
          canvas.drawPath(
            path,
            Paint()
              ..shader = gradient
              ..color = color.withValues(alpha: opacity),
          );
        }
      }
      final path = beuiXYLinePath(pathPoints, curve: curve);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      rows != oldDelegate.rows ||
      seriesCount != oldDelegate.seriesCount ||
      points != oldDelegate.points ||
      categories != oldDelegate.categories ||
      curve != oldDelegate.curve ||
      variant != oldDelegate.variant ||
      baseline != oldDelegate.baseline ||
      strokeWidth != oldDelegate.strokeWidth ||
      colors != oldDelegate.colors;
}
