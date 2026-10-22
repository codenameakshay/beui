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
    final height = 220.0 + math.min(math.max(maxRank - 1, 1), 8) * 20.0;
    return _BumpScope(
      rows: rows,
      periods: widget.periods,
      activeId: activeId,
      onActive: setActiveId,
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
    required this.onActive,
    required this.label,
    required this.maxRank,
    required this.height,
    required super.child,
  });
  final List<_BumpRow> rows;
  final List<String> periods;
  final String? activeId;
  final ValueChanged<String?> onActive;
  final String label;
  final int maxRank;
  final double height;

  static _BumpScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BumpScope>()!;

  @override
  bool updateShouldNotify(_BumpScope old) =>
      rows != old.rows || periods != old.periods || activeId != old.activeId;
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
        const left = 30.0, right = 78.0, top = 24.0, bottom = 28.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 560.0;
        final plotWidth = math.max(1, width - left - right);
        final plotHeight = scope.height - top - bottom;
        double x(int period) => scope.periods.length <= 1
            ? left + plotWidth / 2
            : left + period * plotWidth / (scope.periods.length - 1);
        double y(int rank) => scope.maxRank <= 1
            ? top + plotHeight / 2
            : top + (rank - 1) * plotHeight / (scope.maxRank - 1);
        return SizedBox(
          height: scope.height,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(width, scope.height),
                painter: _BumpPainter(
                  rows: scope.rows,
                  maxRank: scope.maxRank,
                  activeId: scope.activeId,
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
                      left: (x(j) - 17).clamp(0, width - 34),
                      top: y(rank) + top - 17,
                      width: 34,
                      height: 34,
                      child: Semantics(
                        button: true,
                        selected: scope.activeId == scope.rows[i].series.id,
                        label:
                            '${scope.rows[i].series.name}, ${scope.periods[j]}, rank $rank',
                        child: Tooltip(
                          message:
                              '${scope.rows[i].series.name} · ${scope.periods[j]} · #$rank',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => scope.onActive(
                              scope.activeId == scope.rows[i].series.id
                                  ? null
                                  : scope.rows[i].series.id,
                            ),
                            child: Center(
                              child: Container(
                                width: scope.activeId == scope.rows[i].series.id
                                    ? 14
                                    : 9,
                                height:
                                    scope.activeId == scope.rows[i].series.id
                                    ? 14
                                    : 9,
                                decoration: BoxDecoration(
                                  color: scope.rows[i].color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.background,
                                    width: 2,
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
                  top: scope.height - bottom,
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
              for (var rank = 1; rank <= scope.maxRank; rank++)
                Positioned(
                  left: 0,
                  top: y(rank) + top - 7,
                  width: left - 6,
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              for (final row in scope.rows)
                if (row.ranks.lastOrNull case final rank?)
                  Positioned(
                    left: width - right + 8,
                    top: y(rank) + top - 8,
                    width: right - 8,
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
      canvas.drawLine(
        Offset(left, yy),
        Offset(size.width - right, yy),
        Paint()
          ..color = colors.border.withValues(alpha: .55)
          ..strokeWidth = 1,
      );
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
            selected: scope.activeId == row.series.id,
            dimmed: scope.activeId != null && scope.activeId != row.series.id,
            onPressed: () => scope.onActive(
              scope.activeId == row.series.id ? null : row.series.id,
            ),
          ),
      ],
    );
  }
}
