/// One-hundred-percent stacked bar and area charts.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../motion/tooltip.dart';
import '../motion/_engine.dart';
import '_shared.dart';

/// How composition data is visualized.
enum BeuiCompositionView {
  /// Stacked columns.
  bar,

  /// Stacked areas.
  area,
}

/// A series aligned with the chart's period list.
@immutable
class BeuiCompositionSeries {
  /// Creates a composition series.
  const BeuiCompositionSeries({
    required this.id,
    required this.name,
    required this.color,
    required this.values,
  });

  /// Stable identity.
  final String id;

  /// Display name.
  final String name;

  /// Hex or supported theme-token color.
  final String color;

  /// Nonnegative values aligned with periods. Null or invalid values form a gap.
  final List<num?> values;
}

/// One period's series shares and stack offsets.
@immutable
class BeuiCompositionSegment {
  /// Creates a segment.
  const BeuiCompositionSegment({
    required this.series,
    required this.value,
    required this.share,
    required this.offset,
  });

  /// Source series.
  final BeuiCompositionSeries series;

  /// Exact value, or null for missing data.
  final num? value;

  /// Normalized share from 0 to 100.
  final double share;

  /// Stack offset from the bottom, from 0 to 100.
  final double offset;
}

/// A period and its valid normalized column.
@immutable
class BeuiCompositionColumn {
  /// Creates a column.
  const BeuiCompositionColumn({
    required this.period,
    required this.valid,
    required this.segments,
  });

  /// Period label.
  final String period;

  /// Whether this period has complete valid data and a positive total.
  final bool valid;

  /// Series segments.
  final List<BeuiCompositionSegment> segments;
}

/// Interactive 100% stacked chart, or a scope for its chart parts.
class BeuiCompositionChart extends StatefulWidget {
  /// Creates a composition chart.
  const BeuiCompositionChart({
    required this.series,
    required this.periods,
    super.key,
    this.view = BeuiCompositionView.bar,
    this.period,
    this.defaultPeriod,
    this.onPeriodChange,
    this.formatValue,
    this.label = 'Composition over time',
    this.child,
  });

  /// Series to stack.
  final List<BeuiCompositionSeries> series;

  /// Unique period labels in chronological order.
  final List<String> periods;

  /// Bar or area presentation.
  final BeuiCompositionView view;

  /// Controlled selected period.
  final String? period;

  /// Initial period when uncontrolled.
  final String? defaultPeriod;

  /// Called when the selected period changes.
  final ValueChanged<String>? onPeriodChange;

  /// Value formatter.
  final String Function(num value)? formatValue;

  /// Accessible chart label.
  final String label;

  /// Custom composition. Defaults to plot and legend.
  final Widget? child;

  @override
  State<BeuiCompositionChart> createState() => _BeuiCompositionChartState();
}

class _BeuiCompositionChartState extends State<BeuiCompositionChart>
    with BeuiChartActiveState<BeuiCompositionChart> {
  final FocusNode _inspectorFocusNode = FocusNode();
  final _tooltipAnchor = GlobalKey();
  final _tooltipLink = LayerLink();
  Offset? _pointer;
  bool _keyboard = true;
  bool _pointerFocus = false;
  String? _pinned;
  String? _hovered;
  String? _focused;
  bool _tooltipOpen = false;
  void _setTooltipOpen(bool open) {
    if (_tooltipOpen != open) setState(() => _tooltipOpen = open);
  }

  @override
  String? get widgetActiveId => widget.period;
  @override
  String? get widgetDefaultActiveId => widget.defaultPeriod;
  @override
  ValueChanged<String?>? get widgetOnActiveChange => null;
  @override
  Iterable<String> get knownIds => widget.periods;

  @override
  void initState() {
    super.initState();
    initActive();
  }

  @override
  void dispose() {
    _inspectorFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BeuiCompositionChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (activeId == null) super.setActiveId(null);
    final ids = widget.series.map((row) => row.id).toSet();
    if (!ids.contains(_pinned)) _pinned = null;
    if (!ids.contains(_hovered)) _hovered = null;
    if (!ids.contains(_focused)) _focused = null;
  }

  List<BeuiCompositionColumn> get columns {
    final ids = <String>{};
    final seriesIds = <String>{};
    final rows = widget.series.where((row) => seriesIds.add(row.id)).toList();
    return [
      for (var index = 0; index < widget.periods.length; index++)
        if (ids.add(widget.periods[index]))
          _compositionColumn(widget.periods[index], index, rows),
    ];
  }

  String? get effectivePeriod {
    final items = columns;
    if (items.isEmpty) return null;
    final selected = activeId;
    return items.any((column) => column.period == selected)
        ? selected
        : items.last.period;
  }

  @override
  void setActiveId(String? id) {
    final previous = effectivePeriod;
    super.setActiveId(id);
    if (previous != id && id != null) widget.onPeriodChange?.call(id);
  }

  void selectPeriod(String id) {
    setActiveId(id);
  }

  bool inspectKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final items = columns;
    if (items.isEmpty) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _setTooltipOpen(false);
      return true;
    }
    final current = items.indexWhere((item) => item.period == effectivePeriod);
    final next = switch (key) {
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => items.length - 1,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.arrowUp => (current + 1).clamp(0, items.length - 1),
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.arrowDown => (current - 1).clamp(0, items.length - 1),
      _ => null,
    };
    if (next == null) return false;
    _pointerFocus = false;
    _keyboard = true;
    selectPeriod(items[next].period);
    _setTooltipOpen(true);
    return true;
  }

  void togglePinned(String id) =>
      setState(() => _pinned = _pinned == id ? null : id);
  void hoverSeries(String? id) => setState(() => _hovered = id);
  void focusSeries(String? id) => setState(() => _focused = id);

  void movePointer(Offset position) => setState(() {
    _keyboard = false;
    _pointer = position;
  });

  void clearHighlight() => setState(() {
    _pinned = null;
    _hovered = null;
    _focused = null;
  });

  @override
  Widget build(BuildContext context) => _CompositionScope(
    state: this,
    child: BeuiChartFrame(
      label: widget.label,
      child:
          widget.child ??
          (columns.isEmpty
              ? const BeuiCompositionPlot()
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BeuiCompositionPlot(),
                    SizedBox(height: 16),
                    BeuiCompositionLegend(),
                  ],
                )),
    ),
  );
}

BeuiCompositionColumn _compositionColumn(
  String period,
  int index,
  List<BeuiCompositionSeries> rows,
) {
  final values = rows
      .map((row) => index < row.values.length ? row.values[index] : null)
      .toList();
  final valid =
      values.isNotEmpty &&
      values.every((value) => value != null && value.isFinite && value >= 0);
  final max = valid
      ? values.fold<num>(0, (m, value) => math.max(m, value!))
      : 0;
  final scaledTotal = max > 0
      ? values.fold<double>(0, (sum, value) => sum + (value! / max))
      : 0.0;
  var offset = 0.0;
  final segments = <BeuiCompositionSegment>[];
  for (var i = 0; i < rows.length; i++) {
    final value = values[i];
    final share = scaledTotal > 0
        ? ((value ?? 0) / max / scaledTotal) * 100
        : 0.0;
    segments.add(
      BeuiCompositionSegment(
        series: rows[i],
        value: value,
        share: share,
        offset: offset,
      ),
    );
    offset += share;
  }
  return BeuiCompositionColumn(
    period: period,
    valid: valid && scaledTotal > 0,
    segments: segments,
  );
}

class _CompositionScope extends InheritedWidget {
  const _CompositionScope({required this.state, required super.child});
  final _BeuiCompositionChartState state;

  static _BeuiCompositionChartState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CompositionScope>();
    assert(
      scope != null,
      'Composition chart parts must be inside BeuiCompositionChart.',
    );
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_CompositionScope old) => true;
}

/// Stacked bars or areas with a keyboard-adjustable period range.
class BeuiCompositionPlot extends StatelessWidget {
  /// Creates the plot.
  const BeuiCompositionPlot({super.key, double? height})
    : height = height ?? 320,
      _responsive = height == null;

  /// Plot height.
  final double height;
  final bool _responsive;

  @override
  Widget build(BuildContext context) {
    final state = _CompositionScope.of(context);
    final columns = state.columns;
    final colors = BeuiColors.resolve(context);
    if (columns.isEmpty || state.widget.series.isEmpty) {
      return SizedBox(
        height: 256,
        child: Center(
          child: Text(
            'No composition data',
            style: TextStyle(fontSize: 14, color: colors.mutedForeground),
          ),
        ),
      );
    }
    final selected = state.effectivePeriod!;
    final index = columns.indexWhere((column) => column.period == selected);
    final column = columns[index];
    final format =
        state.widget.formatValue ?? (value) => beuiChartFormatNumber(value);
    final highlight = [state._hovered, state._focused, state._pinned]
        .where((id) => columns.first.segments.any((s) => s.series.id == id))
        .firstOrNull;
    final plotHeight = _responsive
        ? (MediaQuery.sizeOf(context).width < 640 ? 256.0 : 320.0)
        : height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 11,
            height: 16 / 11,
            color: colors.mutedForeground,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${column.period}${column.valid ? '' : ' · No data'}'),
              const Text('100%', style: TextStyle(fontFamily: 'monospace')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              _CompositionOutline(
                offset: 4,
                child: Focus(
                  focusNode: state._inspectorFocusNode,
                  onFocusChange: (focus) {
                    if (!focus) {
                      state._pointerFocus = false;
                      state._setTooltipOpen(false);
                    } else if (!state._pointerFocus) {
                      state._keyboard = true;
                      state._setTooltipOpen(true);
                    }
                  },
                  onKeyEvent: (node, event) {
                    final handled = state.inspectKey(event);
                    return handled
                        ? KeyEventResult.handled
                        : KeyEventResult.ignored;
                  },
                  child: MouseRegion(
                    onEnter: (event) {
                      if (event.kind == PointerDeviceKind.touch) return;
                      state._keyboard = false;
                      state._pointer = event.localPosition;
                      state._setTooltipOpen(true);
                      state.selectPeriod(
                        columns[(event.localPosition.dx /
                                    constraints.maxWidth *
                                    columns.length)
                                .floor()
                                .clamp(0, columns.length - 1)]
                            .period,
                      );
                    },
                    onHover: (event) {
                      if (event.kind == PointerDeviceKind.touch) return;
                      state.movePointer(event.localPosition);
                      if (constraints.maxWidth <= 0) return;
                      final periodIndex =
                          (event.localPosition.dx /
                                  constraints.maxWidth *
                                  columns.length)
                              .floor()
                              .clamp(0, columns.length - 1);
                      state.selectPeriod(columns[periodIndex].period);
                    },
                    onExit: (_) {
                      state._setTooltipOpen(false);
                    },
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (constraints.maxWidth <= 0) return;
                        state._pointerFocus = true;
                        state._inspectorFocusNode.requestFocus();
                        state._keyboard = false;
                        state._pointer = event.localPosition;
                        state._setTooltipOpen(true);
                        final periodIndex =
                            (event.localPosition.dx /
                                    constraints.maxWidth *
                                    columns.length)
                                .floor()
                                .clamp(0, columns.length - 1);
                        state.selectPeriod(columns[periodIndex].period);
                      },
                      onPointerMove: (event) {
                        if (event.buttons != 1) return;
                        state.movePointer(event.localPosition);
                        state.selectPeriod(
                          columns[(event.localPosition.dx /
                                      constraints.maxWidth *
                                      columns.length)
                                  .floor()
                                  .clamp(0, columns.length - 1)]
                              .period,
                        );
                      },
                      onPointerCancel: (_) => state._setTooltipOpen(false),
                      onPointerUp: (event) {
                        if (event.kind == PointerDeviceKind.touch) {
                          state._setTooltipOpen(false);
                        }
                      },
                      child: SizedBox(
                        height: plotHeight,
                        child: Semantics(
                          container: true,
                          slider: true,
                          label:
                              '${state.widget.label}, ${column.period}, ${column.segments.where((segment) => segment.value != null).map((segment) => '${segment.series.name}: ${format(segment.value!)} (${segment.share.toStringAsFixed(1)}%)').join(', ')}',
                          value: column.period,
                          increasedValue: index < columns.length - 1
                              ? columns[index + 1].period
                              : null,
                          decreasedValue: index > 0
                              ? columns[index - 1].period
                              : null,
                          onIncrease: index < columns.length - 1
                              ? () => state.selectPeriod(
                                  columns[index + 1].period,
                                )
                              : null,
                          onDecrease: index > 0
                              ? () => state.selectPeriod(
                                  columns[index - 1].period,
                                )
                              : null,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _CompositionGeometry(
                                  columns: columns,
                                  view: state.widget.view,
                                  colors: colors,
                                  highlight: highlight,
                                ),
                              ),
                              Positioned(
                                left: state._keyboard
                                    ? constraints.maxWidth *
                                          (index + .5) /
                                          columns.length
                                    : state._pointer?.dx ?? 0,
                                top: state._keyboard
                                    ? plotHeight * .3
                                    : state._pointer?.dy ?? 0,
                                child: CompositedTransformTarget(
                                  key: state._tooltipAnchor,
                                  link: state._tooltipLink,
                                  child: const SizedBox.shrink(),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: BeuiChartSpring(
                                    value: (index + .5) / columns.length,
                                    builder: (context, cursor) => CustomPaint(
                                      painter: _CompositionPainter(
                                        columns: const [],
                                        colors: const {},
                                        gridColor: Colors.transparent,
                                        cursor: cursor,
                                        cursorColor: colors.foreground
                                            .withValues(alpha: .7),
                                      ),
                                      child: const SizedBox.expand(),
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
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: BeuiTooltip(
                  open: state._tooltipOpen,
                  onOpenChange: state._setTooltipOpen,
                  delay: Duration.zero,
                  followCursor: true,
                  sideOffset: state._keyboard ? 8 : 12,
                  externalAnchor: state._tooltipAnchor,
                  anchorLink: state._tooltipLink,
                  content: SizedBox(
                    width: math.min(288, MediaQuery.sizeOf(context).width - 38),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          column.period,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!column.valid)
                          Text(
                            'No complete data for this period.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedForeground,
                            ),
                          )
                        else
                          for (var i = 0; i < column.segments.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _compositionTooltipRow(
                              column.segments[i],
                              colors: colors,
                              formatValue: format,
                            ),
                          ],
                      ],
                    ),
                  ),
                  child: const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 11,
            height: 16 / 11,
            color: colors.mutedForeground,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(columns.first.period), Text(columns.last.period)],
          ),
        ),
        Offstage(
          child: Slider(
            value: index.toDouble(),
            min: 0,
            max: (columns.length - 1).toDouble().clamp(1, double.infinity),
            divisions: columns.length > 1 ? columns.length - 1 : null,
            semanticFormatterCallback: (_) => column.period,
            onChanged: columns.length < 2
                ? null
                : (value) => state.selectPeriod(columns[value.round()].period),
          ),
        ),
      ],
    );
  }
}

Widget _compositionTooltipRow(
  BeuiCompositionSegment segment, {
  required BeuiColors colors,
  required String Function(num) formatValue,
}) {
  final muted = TextStyle(fontSize: 11, color: colors.mutedForeground);
  return Row(
    key: ValueKey(segment.series.id),
    mainAxisSize: MainAxisSize.min,
    children: [
      BeuiChartSwatch(
        color: beuiChartColor(segment.series.color, colors),
        size: 6,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          segment.series.name,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: colors.foreground),
        ),
      ),
      const SizedBox(width: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 112),
        child: BeuiChartTicker(
          value: segment.value!,
          duration: const Duration(milliseconds: 200),
          format: formatValue,
          style: muted,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 48,
        child: Align(
          alignment: Alignment.centerRight,
          child: BeuiChartTicker(
            value: segment.share,
            duration: const Duration(milliseconds: 200),
            format: (value) => '${value.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: colors.foreground,
            ),
          ),
        ),
      ),
    ],
  );
}

class _CompositionGeometry extends StatelessWidget {
  const _CompositionGeometry({
    required this.columns,
    required this.view,
    required this.colors,
    required this.highlight,
  });
  final List<BeuiCompositionColumn> columns;
  final BeuiCompositionView view;
  final BeuiColors colors;
  final String? highlight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CompositionPainter(
                columns: const [],
                colors: const {},
                gridColor: colors.border,
                cursor: 0,
                cursorColor: Colors.transparent,
              ),
            ),
          ),
          if (view == BeuiCompositionView.bar)
            for (var i = 0; i < columns.length; i++)
              if (columns[i].valid)
                for (final segment in columns[i].segments)
                  BeuiChartSpringRect(
                    key: ValueKey('${columns[i].period}/${segment.series.id}'),
                    value: Rect.fromLTWH(
                      width * (i + .1) / columns.length,
                      height * (1 - (segment.offset + segment.share) / 100),
                      width * .8 / columns.length,
                      height * segment.share / 100,
                    ),
                    builder: (context, rect) => Positioned.fromRect(
                      rect: rect,
                      child: BeuiChartSpring(
                        value:
                            highlight != null && highlight != segment.series.id
                            ? .18
                            : .9,
                        builder: (context, opacity) => ColoredBox(
                          color: beuiChartColor(
                            segment.series.color,
                            colors,
                          ).withValues(alpha: opacity.clamp(0, 1)),
                        ),
                      ),
                    ),
                  ),
          if (view == BeuiCompositionView.area)
            for (var row = 0; row < columns.first.segments.length; row++)
              Positioned.fill(
                key: ValueKey(columns.first.segments[row].series.id),
                child: BeuiChartTween(
                  from: 0,
                  value:
                      highlight != null &&
                          highlight != columns.first.segments[row].series.id
                      ? .18
                      : .9,
                  duration: const Duration(milliseconds: 180),
                  motion: const CurvedMotion(
                    Duration(milliseconds: 180),
                    Cubic(0, 0, .58, 1),
                  ),
                  builder: (context, opacity) => CustomPaint(
                    painter: _CompositionPainter(
                      columns: columns,
                      colors: {
                        for (final segment in columns.first.segments)
                          segment.series.id: beuiChartColor(
                            segment.series.color,
                            colors,
                          ),
                      },
                      gridColor: Colors.transparent,
                      cursor: 0,
                      cursorColor: Colors.transparent,
                      areaRow: row,
                      opacity: opacity,
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

class _CompositionPainter extends CustomPainter {
  _CompositionPainter({
    required this.columns,
    required this.colors,
    required this.gridColor,
    required this.cursor,
    required this.cursorColor,
    this.areaRow,
    this.opacity = .9,
  });

  final List<BeuiCompositionColumn> columns;
  final Map<String, Color> colors;
  final Color gridColor;
  final int? areaRow;
  final double opacity;
  final double cursor;
  final Color cursorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final count = columns.length;
    if (columns.isNotEmpty) {
      final rowCount = columns.first.segments.length;
      for (var row = 0; row < rowCount; row++) {
        if (areaRow != null && row != areaRow) continue;
        final paint = Paint()
          ..color =
              (colors[columns.first.segments[row].series.id] ?? Colors.blue)
                  .withValues(alpha: opacity)
          ..style = PaintingStyle.fill;
        var run = <int>[];
        void flush() {
          if (run.isEmpty) return;
          final path = Path();
          if (run.length == 1) {
            final c = run.single;
            final seg = columns[c].segments[row];
            path.addRect(
              Rect.fromLTRB(
                size.width * c / count,
                size.height * (1 - (seg.offset + seg.share) / 100),
                size.width * (c + 1) / count,
                size.height * (1 - seg.offset / 100),
              ),
            );
            canvas.drawPath(path, paint);
            run = [];
            return;
          }
          for (var j = 0; j < run.length; j++) {
            final c = run[j];
            final seg = columns[c].segments[row];
            final point = Offset(
              size.width * (c + 0.5) / count,
              size.height * (1 - (seg.offset + seg.share) / 100),
            );
            if (j == 0) {
              path.moveTo(point.dx, point.dy);
            } else {
              path.lineTo(point.dx, point.dy);
            }
          }
          for (final c in run.reversed) {
            final seg = columns[c].segments[row];
            path.lineTo(
              size.width * (c + 0.5) / count,
              size.height * (1 - seg.offset / 100),
            );
          }
          path.close();
          canvas.drawPath(path, paint);
          run = [];
        }

        for (var c = 0; c < count; c++) {
          if (columns[c].valid) {
            run.add(c);
          } else {
            flush();
          }
        }
        flush();
      }
    }
    final x = cursor * size.width;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + 3, size.height)),
        Paint()
          ..color = cursorColor
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_CompositionPainter old) => true;
}

/// Interactive series legend with a pinned state exposed to semantics.
class BeuiCompositionLegend extends StatelessWidget {
  /// Creates the legend.
  const BeuiCompositionLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final state = _CompositionScope.of(context);
    final colors = BeuiColors.resolve(context);
    final column = state.columns
        .where((item) => item.period == state.effectivePeriod)
        .firstOrNull;
    if (column == null) return const SizedBox.shrink();
    final highlight = [
      state._hovered,
      state._focused,
      state._pinned,
    ].where((id) => column.segments.any((s) => s.series.id == id)).firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 900
            ? 6
            : constraints.maxWidth >= 480
            ? 3
            : 2;
        final width = math.max(
          0.0,
          (constraints.maxWidth - (count - 1) * 16) / count,
        );
        return Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final segment in column.segments)
              SizedBox(
                key: ValueKey('composition-legend-${segment.series.id}'),
                width: width,
                height: 48,
                child: BeuiChartTween(
                  value: highlight != null && highlight != segment.series.id
                      ? .4
                      : 1,
                  duration: const Duration(milliseconds: 150),
                  motion: const CurvedMotion(
                    Duration(milliseconds: 150),
                    Cubic(.4, 0, .2, 1),
                  ),
                  builder: (context, opacity) => Opacity(
                    opacity: opacity.clamp(0, 1),
                    child: MouseRegion(
                      onEnter: (event) {
                        if (event.kind != PointerDeviceKind.touch) {
                          state.hoverSeries(segment.series.id);
                        }
                      },
                      onExit: (event) {
                        if (event.kind != PointerDeviceKind.touch) {
                          state.hoverSeries(null);
                        }
                      },
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onFocusChange: (focused) => state.focusSeries(
                          focused ? segment.series.id : null,
                        ),
                        onKeyEvent: (_, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.escape) {
                            state.clearHighlight();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Semantics(
                          button: true,
                          toggled: state._pinned == segment.series.id,
                          label: 'Highlight ${segment.series.name}',
                          child: _CompositionOutline(
                            offset: 2,
                            radius: 6,
                            child: TextButton(
                              onPressed: () =>
                                  state.togglePinned(segment.series.id),
                              style: ButtonStyle(
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                ),
                                foregroundColor: WidgetStatePropertyAll(
                                  colors.foreground,
                                ),
                                backgroundColor: WidgetStatePropertyAll(
                                  state._pinned == segment.series.id
                                      ? colors.muted.withValues(alpha: .6)
                                      : Colors.transparent,
                                ),
                                overlayColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                                shape: WidgetStatePropertyAll(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: beuiChartColor(
                                        segment.series.color,
                                        colors,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          segment.series.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 16 / 12,
                                            fontWeight: FontWeight.w400,
                                            color: colors.mutedForeground,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          column.valid
                                              ? '${segment.share.toStringAsFixed(1)}%'
                                              : '—',
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 16 / 12,
                                            fontWeight: FontWeight.w400,
                                            fontFamily: 'monospace',
                                            color: colors.foreground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
  }
}

class _CompositionOutline extends StatefulWidget {
  const _CompositionOutline({
    required this.child,
    required this.offset,
    this.radius = 0,
  });
  final Widget child;
  final double offset;
  final double radius;

  @override
  State<_CompositionOutline> createState() => _CompositionOutlineState();
}

class _CompositionOutlineState extends State<_CompositionOutline> {
  bool _focused = false;
  bool _pointerDriven = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) => setState(() {
      _focused = focused;
      if (!focused) _pointerDriven = false;
    }),
    onKeyEvent: (_, _) {
      if (_pointerDriven) setState(() => _pointerDriven = false);
      return KeyEventResult.ignored;
    },
    child: Listener(
      onPointerDown: (_) => setState(() => _pointerDriven = true),
      child: CustomPaint(
        foregroundPainter: _focused && !_pointerDriven
            ? _CompositionOutlinePainter(
                BeuiColors.resolve(context).ring,
                widget.offset,
                widget.radius,
              )
            : null,
        child: widget.child,
      ),
    ),
  );
}

class _CompositionOutlinePainter extends CustomPainter {
  const _CompositionOutlinePainter(this.color, this.offset, this.radius);
  final Color color;
  final double offset;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(offset + 1),
      Radius.circular(radius == 0 ? 0 : radius + offset + 1),
    ),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  @override
  bool shouldRepaint(_CompositionOutlinePainter old) =>
      old.color != color || old.offset != offset || old.radius != radius;
}
