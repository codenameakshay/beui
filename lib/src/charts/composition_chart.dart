/// One-hundred-percent stacked bar and area charts.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
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
    this.label = 'Composition chart',
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
    with BeuiChartActiveState<BeuiCompositionChart>, BeuiChartInspectorKeys {
  final FocusNode _inspectorFocusNode = FocusNode();
  String? _pinned;
  String? _hovered;
  String? _focused;
  String? _hoveredPeriod;
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
  List<String> get inspectableIds => widget.periods.toSet().toList();

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
    final selected = _hoveredPeriod ?? activeId;
    return items.any((column) => column.period == selected)
        ? selected
        : items.first.period;
  }

  @override
  void setActiveId(String? id) {
    final previous = activeId;
    super.setActiveId(id);
    if (previous != id && id != null) widget.onPeriodChange?.call(id);
  }

  void selectPeriod(String id) {
    setActiveId(id);
  }

  void togglePinned(String id) =>
      setState(() => _pinned = _pinned == id ? null : id);
  void hoverSeries(String? id) => setState(() => _hovered = id);
  void focusSeries(String? id) => setState(() => _focused = id);
  void hoverPeriod(String? id) {
    if (_hoveredPeriod != id) setState(() => _hoveredPeriod = id);
  }

  @override
  Widget build(BuildContext context) => _CompositionScope(
    state: this,
    child: BeuiChartFrame(
      label: widget.label,
      child:
          widget.child ??
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeuiCompositionPlot(),
              SizedBox(height: 16),
              BeuiCompositionLegend(),
            ],
          ),
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
  const BeuiCompositionPlot({super.key, this.height = 320});

  /// Plot height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final state = _CompositionScope.of(context);
    final columns = state.columns;
    final colors = BeuiColors.resolve(context);
    if (columns.isEmpty || state.widget.series.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('No composition data')),
      );
    }
    final selected = state.effectivePeriod!;
    final index = columns.indexWhere((column) => column.period == selected);
    final column = columns[index];
    final format =
        state.widget.formatValue ?? (value) => beuiChartFormatNumber(value);
    final highlight = state._pinned ?? state._focused ?? state._hovered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${column.period}${column.valid ? '' : ' · No data'}'),
            const Text('100%'),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) => BeuiChartTooltip(
            open: state._tooltipOpen,
            onOpenChange: state._setTooltipOpen,
            content: BeuiChartTooltipCard(
              title: column.period,
              details: [
                for (final segment in column.segments)
                  if (segment.value != null)
                    _compositionTooltipRow(
                      segment,
                      colors: colors,
                      formatValue: format,
                    ),
              ],
            ),
            child: Focus(
              focusNode: state._inspectorFocusNode,
              onFocusChange: state._setTooltipOpen,
              onKeyEvent: (node, event) {
                final handled = state.handleInspectorKey(event);
                if (handled) {
                  state.hoverPeriod(null);
                  state._setTooltipOpen(
                    event.logicalKey != LogicalKeyboardKey.escape,
                  );
                }
                return handled
                    ? KeyEventResult.handled
                    : KeyEventResult.ignored;
              },
              child: MouseRegion(
                onHover: (event) {
                  state._setTooltipOpen(true);
                  if (constraints.maxWidth <= 0) return;
                  final periodIndex =
                      (event.localPosition.dx /
                              constraints.maxWidth *
                              columns.length)
                          .floor()
                          .clamp(0, columns.length - 1);
                  state.hoverPeriod(columns[periodIndex].period);
                },
                onExit: (_) {
                  state.hoverPeriod(null);
                  state._setTooltipOpen(false);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (event) {
                    if (constraints.maxWidth <= 0) return;
                    state._inspectorFocusNode.requestFocus();
                    state._setTooltipOpen(true);
                    final periodIndex =
                        (event.localPosition.dx /
                                constraints.maxWidth *
                                columns.length)
                            .floor()
                            .clamp(0, columns.length - 1);
                    state.selectPeriod(columns[periodIndex].period);
                  },
                  child: SizedBox(
                    height: height,
                    child: Semantics(
                      container: true,
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
                          ? () => state.selectPeriod(columns[index + 1].period)
                          : null,
                      onDecrease: index > 0
                          ? () => state.selectPeriod(columns[index - 1].period)
                          : null,
                      child: BeuiChartSpring(
                        value: (index + .5) / columns.length,
                        builder: (context, cursor) => CustomPaint(
                          painter: _CompositionPainter(
                            columns: columns,
                            view: state.widget.view,
                            colors: {
                              for (final row in state.widget.series)
                                row.id: beuiChartColor(row.color, colors),
                            },
                            highlight: highlight,
                            reduce: MediaQuery.disableAnimationsOf(context),
                            cursor: cursor,
                            cursorColor: colors.foreground.withValues(
                              alpha: .7,
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
    mainAxisSize: MainAxisSize.min,
    children: [
      BeuiChartSwatch(
        color: beuiChartColor(segment.series.color, colors),
        size: 7,
      ),
      const SizedBox(width: 5),
      Text('${segment.series.name} ', style: muted),
      BeuiChartTicker(value: segment.value!, format: formatValue, style: muted),
      Text(' · ', style: muted),
      BeuiChartTicker(
        value: segment.share,
        format: (value) => '${value.toStringAsFixed(1)}%',
        style: muted,
      ),
    ],
  );
}

class _CompositionPainter extends CustomPainter {
  _CompositionPainter({
    required this.columns,
    required this.view,
    required this.colors,
    required this.highlight,
    required this.reduce,
    required this.cursor,
    required this.cursorColor,
  });

  final List<BeuiCompositionColumn> columns;
  final BeuiCompositionView view;
  final Map<String, Color> colors;
  final String? highlight;
  final bool reduce;
  final double cursor;
  final Color cursorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final count = columns.length;
    if (view == BeuiCompositionView.bar) {
      final columnWidth = size.width / count;
      for (var c = 0; c < count; c++) {
        final column = columns[c];
        if (!column.valid) continue;
        for (final segment in column.segments) {
          final color = colors[segment.series.id] ?? Colors.blue;
          final paint = Paint()
            ..color = color.withValues(
              alpha: highlight != null && highlight != segment.series.id
                  ? 0.18
                  : 0.9,
            );
          canvas.drawRect(
            Rect.fromLTWH(
              c * columnWidth + columnWidth * 0.1,
              size.height * (1 - segment.offset / 100 - segment.share / 100),
              columnWidth * 0.8,
              size.height * segment.share / 100,
            ),
            paint,
          );
        }
      }
    } else {
      final rowCount = columns.first.segments.length;
      for (var row = 0; row < rowCount; row++) {
        final paint = Paint()
          ..color =
              (colors[columns.first.segments[row].series.id] ?? Colors.blue)
                  .withValues(
                    alpha:
                        highlight != null &&
                            highlight != columns.first.segments[row].series.id
                        ? 0.18
                        : 0.9,
                  )
          ..style = PaintingStyle.fill;
        var run = <int>[];
        void flush() {
          if (run.isEmpty) return;
          final path = Path();
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
          if (run.length == 1) {
            final c = run.single;
            final seg = columns[c].segments[row];
            path
              ..lineTo(
                size.width * (c + 1) / count,
                size.height * (1 - (seg.offset + seg.share) / 100),
              )
              ..lineTo(
                size.width * (c + 1) / count,
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
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final segment in column.segments)
          Semantics(
            button: true,
            toggled: state._pinned == segment.series.id,
            label: segment.series.name,
            child: GestureDetector(
              onTap: () => state.togglePinned(segment.series.id),
              child: MouseRegion(
                onEnter: (_) => state.hoverSeries(segment.series.id),
                onExit: (_) => state.hoverSeries(null),
                child: Focus(
                  onFocusChange: (focused) =>
                      state.focusSeries(focused ? segment.series.id : null),
                  child: BeuiChartLegendItem(
                    color: beuiChartColor(segment.series.color, colors),
                    label: segment.series.name,
                    selected: state._pinned == segment.series.id,
                    dimmed:
                        (state._pinned ?? state._hovered ?? state._focused) !=
                            null &&
                        (state._pinned ?? state._hovered ?? state._focused) !=
                            segment.series.id,
                    onPressed: () => state.togglePinned(segment.series.id),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
