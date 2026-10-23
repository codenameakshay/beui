/// Curved rank histories with selectable series.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '_shared.dart';

/// A series of ranks, one per period. Null values leave gaps in its path.
@immutable
class BeuiBumpSeries {
  /// Creates a ranked series.
  const BeuiBumpSeries({
    required this.id,
    required this.name,
    required this.ranks,
    this.color,
  });

  /// Stable identity.
  final String id;

  /// Legend name.
  final String name;

  /// Rank values (starting at 1) aligned with chart periods.
  final List<int?> ranks;

  /// Optional CSS hex color override.
  final String? color;
}

/// Ranking chart with a curved plot, interactive dots and legend.
class BeuiBumpChart extends StatefulWidget {
  /// Creates a bump chart.
  const BeuiBumpChart({
    required this.series,
    required this.periods,
    super.key,
    this.active,
    this.defaultActive,
    this.onActiveChange,
    this.label = 'Bump chart',
    this.child,
  });

  /// Ranked series.
  final List<BeuiBumpSeries> series;

  /// Chronological period labels.
  final List<String> periods;

  /// Controlled selected series ID (null clears selection).
  final String? active;

  /// Initial uncontrolled selected series ID.
  final String? defaultActive;

  /// Called when selection changes.
  final ValueChanged<String?>? onActiveChange;

  /// Accessible chart label.
  final String label;

  /// Custom composition; defaults to plot and legend.
  final Widget? child;

  @override
  State<BeuiBumpChart> createState() => _BeuiBumpChartState();
}

class _BeuiBumpChartState extends State<BeuiBumpChart>
    with BeuiChartActiveState<BeuiBumpChart>, BeuiChartInspectorKeys {
  String? _hoveredId;
  String? _focusedId;

  @override
  String? get widgetActiveId => widget.active;
  @override
  String? get widgetDefaultActiveId => widget.defaultActive;
  @override
  ValueChanged<String?>? get widgetOnActiveChange => widget.onActiveChange;
  @override
  Iterable<String> get knownIds => widget.series.map((row) => row.id);
  @override
  List<String> get inspectableIds =>
      widget.series.map((row) => row.id).toList();

  @override
  void initState() {
    super.initState();
    initActive();
  }

  @override
  void didUpdateWidget(covariant BeuiBumpChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hoveredId != null &&
        !widget.series.any((row) => row.id == _hoveredId)) {
      _hoveredId = null;
    }
    if (_focusedId != null &&
        !widget.series.any((row) => row.id == _focusedId)) {
      _focusedId = null;
    }
  }

  void _setHoveredId(String? id) {
    if (id != null && !widget.series.any((row) => row.id == id)) return;
    if (_hoveredId != id) setState(() => _hoveredId = id);
  }

  void _setFocusedId(String? id) {
    if (id != null && !widget.series.any((row) => row.id == id)) return;
    if (_focusedId != id) setState(() => _focusedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final seen = <String>{};
    final rows = <_BumpRow>[];
    for (var i = 0; i < widget.series.length; i++) {
      final row = widget.series[i];
      if (!seen.add(row.id)) continue;
      final ranks = List<int?>.generate(widget.periods.length, (index) {
        if (index >= row.ranks.length) return null;
        final rank = row.ranks[index];
        return rank != null && rank > 0 ? rank : null;
      });
      rows.add(
        _BumpRow(
          series: row,
          ranks: ranks,
          color: beuiChartColor(
            row.color,
            colors,
            fallback: beuiBumpPalette[i % beuiBumpPalette.length],
          ),
        ),
      );
    }
    final rankValues =
        rows.expand((row) => row.ranks.whereType<int>()).toSet().toList()
          ..sort();
    final maxRank = rankValues.isEmpty ? 1 : rankValues.last;
    final height = 28.0 + math.min(math.max(maxRank - 1, 1), 8) * 44.0 + 36;
    return _BumpScope(
      rows: rows,
      periods: widget.periods,
      activeId: activeId,
      hoveredId: _hoveredId,
      focusedId: _focusedId,
      onActive: setActiveId,
      onHover: _setHoveredId,
      onFocus: _setFocusedId,
      label: widget.label,
      maxRank: maxRank,
      height: height,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => handleInspectorKey(event)
            ? KeyEventResult.handled
            : KeyEventResult.ignored,
        child: BeuiChartFrame(
          label: widget.label,
          child:
              widget.child ??
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BeuiBumpPlot(),
                  SizedBox(height: 12),
                  BeuiBumpLegend(),
                ],
              ),
        ),
      ),
    );
  }
}

class _BumpRow {
  const _BumpRow({
    required this.series,
    required this.ranks,
    required this.color,
  });
  final BeuiBumpSeries series;
  final List<int?> ranks;
  final Color color;
}

class _BumpScope extends InheritedWidget {
  const _BumpScope({
    required this.rows,
    required this.periods,
    required this.activeId,
    required this.hoveredId,
    required this.focusedId,
    required this.onActive,
    required this.onHover,
    required this.onFocus,
    required this.label,
    required this.maxRank,
    required this.height,
    required super.child,
  });
  final List<_BumpRow> rows;
  final List<String> periods;
  final String? activeId;
  final String? hoveredId;
  final String? focusedId;
  final ValueChanged<String?> onActive;
  final ValueChanged<String?> onHover;
  final ValueChanged<String?> onFocus;
  final String label;
  final int maxRank;
  final double height;

  static _BumpScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BumpScope>()!;

  @override
  bool updateShouldNotify(_BumpScope old) =>
      rows != old.rows ||
      periods != old.periods ||
      activeId != old.activeId ||
      hoveredId != old.hoveredId ||
      focusedId != old.focusedId;

  String? get highlightedId => hoveredId ?? focusedId ?? activeId;
}

/// Curved rank paths and a dot for each observed rank.
class BeuiBumpPlot extends StatelessWidget {
  /// Creates the plot.
  const BeuiBumpPlot({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = _BumpScope.of(context);
    final colors = BeuiColors.resolve(context);
    if (scope.rows.isEmpty || scope.periods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No ranking data')),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 560.0;
        final scale = width / 560;
        final left = 32 * scale,
            right = 100 * scale,
            top = 28 * scale,
            bottom = 36 * scale;
        final height = scope.height * scale;
        final plotWidth = math.max(1, width - left - right);
        final plotHeight = height - top - bottom;
        double x(int period) => scope.periods.length <= 1
            ? left + plotWidth / 2
            : left + period * plotWidth / (scope.periods.length - 1);
        double y(int rank) => scope.maxRank <= 1
            ? top + plotHeight / 2
            : top + (rank - 1) * plotHeight / (scope.maxRank - 1);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(width, height),
                painter: _BumpPainter(
                  rows: scope.rows,
                  maxRank: scope.maxRank,
                  activeId: scope.highlightedId,
                  left: left,
                  right: right,
                  top: top,
                  bottom: bottom,
                  colors: colors,
                ),
              ),
              for (var i = 0; i < scope.rows.length; i++)
                for (var j = 0; j < scope.periods.length; j++)
                  if (scope.rows[i].ranks[j] case final rank?)
                    Positioned(
                      left: x(j) - 14,
                      top: y(rank) - 14,
                      width: 28,
                      height: 28,
                      child: Semantics(
                        button: true,
                        selected:
                            scope.highlightedId == scope.rows[i].series.id,
                        label:
                            '${scope.rows[i].series.name}, ${scope.periods[j]}, rank $rank',
                        child: MouseRegion(
                          onEnter: (_) =>
                              scope.onHover(scope.rows[i].series.id),
                          onExit: (_) {
                            if (scope.hoveredId == scope.rows[i].series.id) {
                              scope.onHover(null);
                            }
                          },
                          child: BeuiChartTooltip(
                            content: BeuiChartTooltipCard(
                              title:
                                  '${scope.rows[i].series.name} · ${scope.periods[j]}',
                              details: [
                                BeuiChartTicker(
                                  value: rank,
                                  duration: const Duration(milliseconds: 350),
                                  format: (value) => '#${value.round()}',
                                ),
                                Text(
                                  j == 0 || scope.rows[i].ranks[j - 1] == null
                                      ? 'No previous rank'
                                      : scope.rows[i].ranks[j - 1] == rank
                                      ? 'No change'
                                      : '${scope.rows[i].ranks[j - 1]! > rank ? 'Up' : 'Down'} ${(scope.rows[i].ranks[j - 1]! - rank).abs()} ${(scope.rows[i].ranks[j - 1]! - rank).abs() == 1 ? 'place' : 'places'}',
                                ),
                                if (j > 0 && scope.rows[i].ranks[j - 1] != null)
                                  Text(
                                    'Previously #${scope.rows[i].ranks[j - 1]} in ${scope.periods[j - 1]}',
                                  ),
                              ],
                            ),
                            child: InkWell(
                              key: ValueKey(
                                'bump-node-${scope.rows[i].series.id}-$j',
                              ),
                              onFocusChange: (focused) => scope.onFocus(
                                focused ? scope.rows[i].series.id : null,
                              ),
                              customBorder: const CircleBorder(),
                              onTap: () => scope.onActive(
                                scope.activeId == scope.rows[i].series.id
                                    ? null
                                    : scope.rows[i].series.id,
                              ),
                              child: Semantics(
                                button: true,
                                selected:
                                    scope.highlightedId ==
                                    scope.rows[i].series.id,
                                label:
                                    '${scope.rows[i].series.name}, ${scope.periods[j]}, rank $rank',
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: colors.background,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: scope.rows[i].color,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      '$rank',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                        color: scope.rows[i].color,
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
              for (var i = 0; i < scope.periods.length; i++)
                Positioned(
                  left: x(i) - 28,
                  top: height - 18 * scale,
                  width: 56,
                  child: Text(
                    scope.periods[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              for (final row in scope.rows)
                if (row.ranks.lastOrNull case final rank?)
                  Positioned(
                    left: width - right + 18 * scale,
                    top: y(rank) - 8,
                    width: right - 18 * scale,
                    child: Text(
                      row.series.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: row.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              for (final row in scope.rows)
                Semantics(
                  container: true,
                  label:
                      'Ranking data: ${row.series.name}. ${[for (var index = 0; index < scope.periods.length; index++)
                        if (row.ranks[index] case final rank?) '${scope.periods[index]} rank $rank' else '${scope.periods[index]} no data'].join(', ')}',
                  child: const SizedBox.shrink(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BumpPainter extends CustomPainter {
  const _BumpPainter({
    required this.rows,
    required this.maxRank,
    required this.activeId,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.colors,
  });
  final List<_BumpRow> rows;
  final int maxRank;
  final String? activeId;
  final double left, right, top, bottom;
  final BeuiColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - left - right;
    final plotHeight = size.height - top - bottom;
    double x(int period) => rows.first.ranks.length <= 1
        ? left + plotWidth / 2
        : left + period * plotWidth / (rows.first.ranks.length - 1);
    double y(int rank) => maxRank <= 1
        ? top + plotHeight / 2
        : top + (rank - 1) * plotHeight / (maxRank - 1);
    for (var rank = 1; rank <= maxRank; rank++) {
      final yy = y(rank);
      for (var xx = left; xx < size.width - right; xx += 7) {
        canvas.drawLine(
          Offset(xx, yy),
          Offset(math.min(xx + 2, size.width - right), yy),
          Paint()
            ..color = colors.border
            ..strokeWidth = 1,
        );
      }
    }
    for (final row in rows) {
      final path = Path();
      Offset? previous;
      for (var i = 0; i < row.ranks.length; i++) {
        final rank = row.ranks[i];
        if (rank == null) {
          previous = null;
          continue;
        }
        final point = Offset(x(i), y(rank));
        if (previous == null) {
          path.moveTo(point.dx, point.dy);
        } else {
          final middle = (previous.dx + point.dx) / 2;
          path.cubicTo(
            middle,
            previous.dy,
            middle,
            point.dy,
            point.dx,
            point.dy,
          );
        }
        previous = point;
      }
      final selected = activeId == row.series.id;
      final dimmed = activeId != null && !selected;
      canvas.drawPath(
        path,
        Paint()
          ..color = row.color.withValues(alpha: dimmed ? .2 : 1)
          ..strokeWidth = selected ? 3 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BumpPainter old) =>
      rows != old.rows || maxRank != old.maxRank || activeId != old.activeId;
}

/// Toggleable series legend.
class BeuiBumpLegend extends StatelessWidget {
  /// Creates the legend buttons.
  const BeuiBumpLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = _BumpScope.of(context);
    return BeuiChartLegend(
      children: [
        for (final row in scope.rows)
          BeuiChartLegendItem(
            color: row.color,
            label: row.series.name,
            selected: scope.highlightedId == row.series.id,
            dimmed:
                scope.highlightedId != null &&
                scope.highlightedId != row.series.id,
            onHover: (hovering) {
              if (hovering) {
                scope.onHover(row.series.id);
              } else if (scope.hoveredId == row.series.id) {
                scope.onHover(null);
              }
            },
            onPressed: () => scope.onActive(
              scope.activeId == row.series.id ? null : row.series.id,
            ),
          ),
      ],
    );
  }
}
