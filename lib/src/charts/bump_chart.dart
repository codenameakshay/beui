/// Curved rank histories with selectable series.
library;

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

import '../theme/beui_colors.dart';
import '../motion/_engine.dart';
import '../tokens/motion.dart';

import 'package:flutter/services.dart';

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

class _BeuiBumpChartState extends State<BeuiBumpChart> {
  String? _hoveredId;
  String? _focusedId;
  FocusNode? _focusedNode;
  String? _internal;
  String? get activeId {
    final id = widget.active ?? _internal;
    return widget.series.any((row) => row.id == id) ? id : null;
  }

  void _select(String? id) {
    if (widget.active == null) setState(() => _internal = id);
    widget.onActiveChange?.call(id);
  }

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultActive;
  }

  @override
  void didUpdateWidget(covariant BeuiBumpChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.series.any((row) => row.id == _internal)) _internal = null;
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
    if (id == null) _focusedNode = null;
  }

  void _nodeFocus(String id, FocusNode node) {
    if (node.hasFocus) {
      _focusedNode = node;
      _setFocusedId(id);
    } else if (identical(_focusedNode, node)) {
      _setFocusedId(null);
    }
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
            fallback: beuiBumpPalette[(rows.length) % beuiBumpPalette.length],
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
      onActive: _select,
      onHover: _setHoveredId,
      onFocus: _setFocusedId,
      onNodeFocus: _nodeFocus,
      label: widget.label,
      maxRank: maxRank,
      height: height,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: BeuiChartFrame(
          label: widget.label,
          child:
              widget.child ??
              const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BeuiBumpPlot(),
                  SizedBox(height: 20),
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
    required this.onNodeFocus,
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
  final void Function(String, FocusNode) onNodeFocus;
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
    if (scope.periods.isEmpty ||
        !scope.rows.any((row) => row.ranks.any((rank) => rank != null))) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Text(
          'No rankings yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: colors.mutedForeground,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          560.0,
          math.max(
            scope.periods.length * 64.0,
            constraints.maxWidth.isFinite ? constraints.maxWidth : 560.0,
          ),
        );
        final scale = width / 560;
        final height = scope.height * scale;
        double x(int i) =>
            (32 +
                (scope.periods.length <= 1
                    ? 214
                    : i * 428 / (scope.periods.length - 1))) *
            scale;
        double y(int rank) =>
            (28 +
                (scope.maxRank <= 1
                    ? (scope.height - 64) / 2
                    : (rank - 1) * (scope.height - 64) / (scope.maxRank - 1))) *
            scale;
        final targets = <(String, String), Offset>{
          for (final row in scope.rows)
            for (var i = 0; i < scope.periods.length; i++)
              if (row.ranks[i] case final rank?)
                (row.series.id, scope.periods[i]): Offset(x(i), y(rank)),
        };
        return _BumpScrollRegion(
          label: '${scope.label} plot, scroll horizontally for more periods',
          child: SizedBox(
            width: width,
            height: height,
            child: _BumpGeometry(
              targets: targets,
              reduce: MediaQuery.disableAnimationsOf(context),
              builder: (positions) => Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: Size(width, height),
                    painter: _BumpGrid(
                      ranks: scope.rows
                          .expand((r) => r.ranks.whereType<int>())
                          .toSet(),
                      y: y,
                      scale: scale,
                      color: colors.border,
                    ),
                  ),
                  for (var i = 0; i < scope.rows.length; i++)
                    Positioned.fill(
                      key: ValueKey(scope.rows[i].series.id),
                      child: _BumpPathLayer(
                        row: scope.rows[i],
                        index: i,
                        points: [
                          for (final period in scope.periods)
                            positions[(scope.rows[i].series.id, period)],
                        ],
                        scale: scale,
                      ),
                    ),
                  for (var i = 0; i < scope.rows.length; i++)
                    for (var j = 0; j < scope.periods.length; j++)
                      if (positions[(scope.rows[i].series.id, scope.periods[j])]
                          case final point?)
                        Positioned(
                          key: ValueKey((
                            scope.rows[i].series.id,
                            scope.periods[j],
                          )),
                          left: point.dx - 14,
                          top: point.dy - 14,
                          width: 28,
                          height: 28,
                          child: FocusTraversalOrder(
                            order: NumericFocusOrder(
                              1.0 + i * scope.periods.length + j,
                            ),
                            child: _BumpDot(
                              row: scope.rows[i],
                              period: j,
                              seriesIndex: i,
                            ),
                          ),
                        ),
                  for (var i = 0; i < scope.periods.length; i++)
                    Positioned(
                      left: x(i) - 28,
                      top: height - 19 * scale,
                      width: 56,
                      child: Text(
                        scope.periods[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10 * scale,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  for (final row in scope.rows)
                    Semantics(
                      container: true,
                      label:
                          'Ranking data: ${row.series.name}. ${[for (var i = 0; i < scope.periods.length; i++)
                            if (row.ranks[i] case final rank?) '${scope.periods[i]} rank $rank' else '${scope.periods[i]} no data'].join(', ')}',
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BumpScrollRegion extends StatefulWidget {
  const _BumpScrollRegion({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  State<_BumpScrollRegion> createState() => _BumpScrollRegionState();
}

class _BumpScrollRegionState extends State<_BumpScrollRegion> {
  final _scroll = ScrollController();
  bool _ring = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusTraversalOrder(
    order: const NumericFocusOrder(0),
    child: Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
            !_scroll.hasClients) {
          return KeyEventResult.ignored;
        }
        final next = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowRight => _scroll.offset + 40,
          LogicalKeyboardKey.arrowLeft => _scroll.offset - 40,
          LogicalKeyboardKey.home => 0.0,
          LogicalKeyboardKey.end => _scroll.position.maxScrollExtent,
          _ => null,
        };
        if (next == null) return KeyEventResult.ignored;
        _scroll.jumpTo(next.clamp(0, _scroll.position.maxScrollExtent));
        return KeyEventResult.handled;
      },
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _ring = value),
        child: _BumpFocusRing(
          show: _ring,
          radius: 8,
          offset: 2,
          child: Semantics(
            label: widget.label,
            container: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: widget.child,
            ),
          ),
        ),
      ),
    ),
  );
}

class _BumpFocusRing extends StatelessWidget {
  const _BumpFocusRing({
    required this.show,
    required this.radius,
    required this.child,
    this.offset = 4,
  });
  final bool show;
  final double radius, offset;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (show)
        Positioned(
          top: -offset,
          left: -offset,
          right: -offset,
          bottom: -offset,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + offset),
                border: Border.all(
                  color: BeuiColors.resolve(context).ring,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _BumpGeometry extends StatefulWidget {
  const _BumpGeometry({
    required this.targets,
    required this.reduce,
    required this.builder,
  });
  final Map<(String, String), Offset> targets;
  final bool reduce;
  final Widget Function(Map<(String, String), Offset>) builder;
  @override
  State<_BumpGeometry> createState() => _BumpGeometryState();
}

class _BumpGeometryState extends State<_BumpGeometry>
    with TickerProviderStateMixin {
  final _positions =
      <(String, String), (SingleMotionController, SingleMotionController)>{};
  void _changed() => setState(() {});
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_BumpGeometry old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    for (final key in _positions.keys.toList()) {
      if (!widget.targets.containsKey(key)) {
        final pair = _positions.remove(key)!;
        _targets.remove(pair.$1);
        _targets.remove(pair.$2);
        pair.$1.dispose();
        pair.$2.dispose();
      }
    }
    for (final entry in widget.targets.entries) {
      final pair = _positions.putIfAbsent(
        entry.key,
        () => (
          SingleMotionController(
            motion: beuiSpringLayout,
            vsync: this,
            initialValue: entry.value.dx,
          )..addListener(_changed),
          SingleMotionController(
            motion: beuiSpringLayout,
            vsync: this,
            initialValue: entry.value.dy,
          )..addListener(_changed),
        ),
      );
      for (final axis in [
        (pair.$1, entry.value.dx),
        (pair.$2, entry.value.dy),
      ]) {
        if (widget.reduce) {
          axis.$1.stop();
          if (axis.$1.value != axis.$2) axis.$1.value = axis.$2;
        } else if (_targets[axis.$1] != axis.$2) {
          axis.$1.animateTo(axis.$2);
        }
        _targets[axis.$1] = axis.$2;
      }
    }
  }

  final _targets = <SingleMotionController, double>{};
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

Path _bumpPath(List<Offset?> points) {
  final path = Path();
  Offset? previous;
  for (final point in points) {
    if (point == null) {
      previous = null;
      continue;
    }
    if (previous == null) {
      path.moveTo(point.dx, point.dy);
    } else {
      final middle = (previous.dx + point.dx) / 2;
      path.cubicTo(middle, previous.dy, middle, point.dy, point.dx, point.dy);
    }
    previous = point;
  }
  return path;
}

class _BumpPathLayer extends StatelessWidget {
  const _BumpPathLayer({
    required this.row,
    required this.index,
    required this.points,
    required this.scale,
  });
  final _BumpRow row;
  final int index;
  final List<Offset?> points;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final scope = _BumpScope.of(context);
    final active = scope.highlightedId == row.series.id;
    final dimmed = scope.highlightedId != null && !active;
    final path = _bumpPath(points);
    return BeuiChartTween(
      from: 0,
      value: dimmed ? .22 : 1,
      duration: const Duration(milliseconds: 180),
      builder: (context, opacity) => Opacity(
        opacity: opacity.clamp(0, 1),
        child: Stack(
          children: [
            Positioned.fill(
              child: BeuiChartTween(
                from: 0,
                value: 1,
                duration: const Duration(milliseconds: 280),
                delay: Duration(milliseconds: math.min(index, 4) * 25),
                isMovement: true,
                builder: (context, reveal) => ClipRect(
                  clipper: _BumpReveal(reveal),
                  child: MouseRegion(
                    hitTestBehavior: HitTestBehavior.translucent,
                    onHover: (event) {
                      if (event.kind == PointerDeviceKind.touch) return;
                      // The source uses a 16px transparent stroke as the path hit target.
                      final near = _nearBumpPath(
                        path,
                        event.localPosition,
                        8 * scale,
                      );
                      if (near) {
                        scope.onHover(row.series.id);
                      } else if (scope.hoveredId == row.series.id) {
                        scope.onHover(null);
                      }
                    },
                    onExit: (event) {
                      if (event.kind == PointerDeviceKind.touch) return;
                      if (scope.hoveredId == row.series.id) scope.onHover(null);
                    },
                    child: BeuiChartTween(
                      value: active ? .16 : 0,
                      duration: const Duration(milliseconds: 180),
                      builder: (context, glow) => CustomPaint(
                        painter: _BumpPainter(
                          path: path,
                          color: row.color,
                          glow: glow,
                          scale: scale,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (points.lastOrNull case final last?)
              Positioned(
                left: last.dx + 18 * scale,
                top: last.dy - 6 * scale,
                child: IgnorePointer(
                  child: Text(
                    row.series.name.length > 12
                        ? '${row.series.name.substring(0, 11)}…'
                        : row.series.name,
                    style: TextStyle(
                      fontSize: 10 * scale,
                      color: row.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _nearBumpPath(Path path, Offset point, double tolerance) {
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d <= metric.length; d += 3) {
      if ((metric.getTangentForOffset(d)!.position - point).distance <=
          tolerance) {
        return true;
      }
    }
  }
  return false;
}

class _BumpReveal extends CustomClipper<Rect> {
  const _BumpReveal(this.value);
  final double value;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * value, size.height);
  @override
  bool shouldReclip(_BumpReveal old) => old.value != value;
}

class _BumpPainter extends CustomPainter {
  const _BumpPainter({
    required this.path,
    required this.color,
    required this.glow,
    required this.scale,
  });
  final Path path;
  final Color color;
  final double glow;
  final double scale;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2 * scale
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: glow)
        ..strokeWidth = 5 * scale
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool? hitTest(Offset position) => _nearBumpPath(path, position, 8 * scale);
  @override
  bool shouldRepaint(_BumpPainter old) => true;
}

class _BumpGrid extends CustomPainter {
  const _BumpGrid({
    required this.ranks,
    required this.y,
    required this.scale,
    required this.color,
  });
  final Set<int> ranks;
  final double Function(int) y;
  final double scale;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    for (final rank in ranks) {
      for (var x = 32 * scale; x < size.width - 100 * scale; x += 7 * scale) {
        canvas.drawLine(
          Offset(x, y(rank)),
          Offset(math.min(x + 2 * scale, size.width - 100 * scale), y(rank)),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BumpGrid old) => true;
}

class _BumpDot extends StatefulWidget {
  const _BumpDot({
    required this.row,
    required this.period,
    required this.seriesIndex,
  });
  final _BumpRow row;
  final int period, seriesIndex;
  @override
  State<_BumpDot> createState() => _BumpDotState();
}

class _BumpDotState extends State<_BumpDot> {
  bool _hovered = false;
  bool _tooltipOpen = false;
  bool _ring = false;
  bool _touch = false;
  bool _touchWasOpen = false;
  bool _pointerFocus = false;
  Timer? _hoverDelay;
  final _focus = FocusNode();
  @override
  void dispose() {
    _hoverDelay?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _BumpScope.of(context);
    final row = widget.row;
    final rank = row.ranks[widget.period]!;
    final previous = widget.period == 0 ? null : row.ranks[widget.period - 1];
    final active = scope.highlightedId == row.series.id;
    final dimmed = scope.highlightedId != null && !active;
    final change = previous == null ? null : previous - rank;
    final changeText = change == null
        ? 'No previous rank'
        : change == 0
        ? 'No change'
        : '${change > 0 ? 'Up' : 'Down'} ${change.abs()} ${change.abs() == 1 ? 'place' : 'places'}';
    void select() =>
        scope.onActive(scope.activeId == row.series.id ? null : row.series.id);
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && _pointerFocus) {
          setState(() => _pointerFocus = false);
        }
        if (event.logicalKey == LogicalKeyboardKey.enter &&
                (event is KeyDownEvent || event is KeyRepeatEvent) ||
            event.logicalKey == LogicalKeyboardKey.space &&
                event is KeyUpEvent) {
          select();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.space) {
          return KeyEventResult.handled;
        }
        if ([
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.home,
          LogicalKeyboardKey.end,
        ].contains(event.logicalKey)) {
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape &&
            (event is KeyDownEvent || event is KeyRepeatEvent)) {
          _hoverDelay?.cancel();
          scope.onActive(null);
          scope.onFocus(null);
          scope.onHover(null);
          setState(() => _tooltipOpen = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusableActionDetector(
        focusNode: _focus,
        onShowFocusHighlight: (value) => setState(() => _ring = value),
        onFocusChange: (focused) {
          if (!focused || !_pointerFocus) {
            setState(() => _tooltipOpen = focused);
          }
          scope.onNodeFocus(row.series.id, _focus);
          if (!focused) _pointerFocus = false;
        },
        child: Semantics(
          key: ValueKey('bump-node-${row.series.id}-${widget.period}'),
          button: true,
          selected: scope.activeId == row.series.id,
          label:
              '${row.series.name}, ${scope.periods[widget.period]}: rank $rank',
          child: MouseRegion(
            onEnter: (event) {
              if (event.kind == PointerDeviceKind.touch) return;
              setState(() {
                _hovered = true;
              });
              _hoverDelay?.cancel();
              _hoverDelay = Timer(const Duration(milliseconds: 60), () {
                if (mounted) setState(() => _tooltipOpen = true);
              });
              scope.onHover(row.series.id);
            },
            onExit: (event) {
              if (event.kind == PointerDeviceKind.touch) return;
              _hoverDelay?.cancel();
              setState(() {
                _hovered = false;
                if (!_focus.hasFocus || _pointerFocus) _tooltipOpen = false;
              });
              scope.onHover(null);
            },
            child: BeuiChartTooltip(
              open: _tooltipOpen,
              onOpenChange: (open) => setState(() => _tooltipOpen = open),
              content: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 132),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          row.series.name,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: BeuiColors.resolve(context).mutedForeground,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          scope.periods[widget.period],
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: BeuiColors.resolve(context).mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#$rank',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            height: 28 / 18,
                            fontWeight: FontWeight.w500,
                            color: row.color,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          changeText,
                          style: const TextStyle(fontSize: 12, height: 16 / 12),
                        ),
                      ],
                    ),
                    if (previous != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Previously #$previous in ${scope.periods[widget.period - 1]}',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: BeuiColors.resolve(context).mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              child: Listener(
                onPointerDown: (event) {
                  _touch = event.kind == PointerDeviceKind.touch;
                  _touchWasOpen = _tooltipOpen;
                  _pointerFocus = true;
                  _hoverDelay?.cancel();
                  if (!_touch) setState(() => _tooltipOpen = false);
                  _focus.requestFocus();
                },
                child: GestureDetector(
                  onTap: () {
                    if (_touch) setState(() => _tooltipOpen = !_touchWasOpen);
                    select();
                  },
                  child: _BumpFocusRing(
                    show: _ring && !_pointerFocus,
                    radius: 14,
                    child: BeuiChartTween(
                      from: .85,
                      value:
                          _hovered && !MediaQuery.disableAnimationsOf(context)
                          ? 1.12
                          : 1,
                      duration: const Duration(milliseconds: 180),
                      motion: beuiSpringPress,
                      isMovement: true,
                      builder: (context, outerScale) => Transform.scale(
                        scale: outerScale,
                        child: BeuiChartTween(
                          from: MediaQuery.disableAnimationsOf(context)
                              ? null
                              : 0,
                          value: dimmed ? .22 : 1,
                          duration: const Duration(milliseconds: 180),
                          builder: (context, opacity) => Opacity(
                            opacity: opacity.clamp(0, 1),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                BeuiChartTween(
                                  value: active ? .12 : 0,
                                  duration: const Duration(milliseconds: 150),
                                  builder: (context, glow) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: row.color.withValues(
                                        alpha: glow.clamp(0, 1),
                                      ),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                                BeuiChartTween(
                                  from: .85,
                                  value: 1,
                                  motion: beuiSpringPress,
                                  duration: const Duration(milliseconds: 180),
                                  delay: Duration(
                                    milliseconds:
                                        math.min(widget.period, 8) * 25 +
                                        math.min(widget.seriesIndex, 4) * 15,
                                  ),
                                  isMovement: true,
                                  builder: (context, innerScale) =>
                                      Transform.scale(
                                        scale: innerScale,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: BeuiColors.resolve(
                                              context,
                                            ).background,
                                            border: Border.all(
                                              color: row.color,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            '$rank',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: row.color,
                                            ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggleable series legend.
class BeuiBumpLegend extends StatelessWidget {
  /// Creates the legend buttons.
  const BeuiBumpLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = _BumpScope.of(context);
    final columns = MediaQuery.sizeOf(context).width >= 640 ? 3 : 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - (columns - 1) * 20) / columns;
        return Wrap(
          spacing: 20,
          runSpacing: 4,
          children: [
            for (var i = 0; i < scope.rows.length; i++)
              SizedBox(
                width: width,
                child: FocusTraversalOrder(
                  order: NumericFocusOrder(1000000.0 + i),
                  child: _BumpLegendButton(
                    key: ValueKey(scope.rows[i].series.id),
                    row: scope.rows[i],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BumpLegendButton extends StatefulWidget {
  const _BumpLegendButton({required this.row, super.key});
  final _BumpRow row;
  @override
  State<_BumpLegendButton> createState() => _BumpLegendButtonState();
}

class _BumpLegendButtonState extends State<_BumpLegendButton> {
  final _focus = FocusNode();
  bool _ring = false;
  bool _pointerFocus = false;
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _BumpScope.of(context);
    final colors = BeuiColors.resolve(context);
    final row = widget.row;
    final first = row.ranks.firstOrNull;
    final last = row.ranks.lastOrNull;
    final gain = first == null || last == null ? null : first - last;
    final dimmed =
        scope.highlightedId != null && scope.highlightedId != row.series.id;
    void select() =>
        scope.onActive(scope.activeId == row.series.id ? null : row.series.id);
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && _pointerFocus) {
          setState(() => _pointerFocus = false);
        }
        if (event.logicalKey == LogicalKeyboardKey.enter &&
                (event is KeyDownEvent || event is KeyRepeatEvent) ||
            event.logicalKey == LogicalKeyboardKey.space &&
                event is KeyUpEvent) {
          select();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.space) {
          return KeyEventResult.handled;
        }
        if ([
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.home,
          LogicalKeyboardKey.end,
        ].contains(event.logicalKey)) {
          return KeyEventResult.handled;
        }
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          scope.onActive(null);
          scope.onFocus(null);
          scope.onHover(null);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusableActionDetector(
        focusNode: _focus,
        onFocusChange: (focused) {
          if (!focused) _pointerFocus = false;
          scope.onNodeFocus(row.series.id, _focus);
        },
        onShowFocusHighlight: (value) => setState(() => _ring = value),
        mouseCursor: SystemMouseCursors.click,
        child: Semantics(
          key: ValueKey('bump-legend-${row.series.id}'),
          button: true,
          selected: scope.activeId == row.series.id,
          label: 'Highlight ${row.series.name}',
          excludeSemantics: true,
          onTap: select,
          child: MouseRegion(
            onEnter: (event) {
              if (event.kind != PointerDeviceKind.touch) {
                scope.onHover(row.series.id);
              }
            },
            onExit: (event) {
              if (event.kind != PointerDeviceKind.touch &&
                  scope.hoveredId == row.series.id) {
                scope.onHover(null);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                _pointerFocus = true;
                _focus.requestFocus();
              },
              onTap: select,
              child: _BumpFocusRing(
                show: _ring && !_pointerFocus,
                radius: 6,
                child: BeuiChartTween(
                  value: dimmed ? .35 : 1,
                  duration: const Duration(milliseconds: 150),
                  builder: (context, opacity) => Opacity(
                    opacity: opacity.clamp(0, 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: scope.activeId == row.series.id
                            ? colors.muted.withValues(alpha: .6)
                            : Colors.transparent,
                      ),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontFamily: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.fontFamily,
                          fontSize: 12,
                          height: 16 / 12,
                          color: colors.foreground,
                        ),
                        child: Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: row.color,
                              ),
                              child: const SizedBox(width: 8, height: 8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                row.series.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              last == null ? '—' : '#$last',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 20),
                              child: Text(
                                gain == null || gain == 0
                                    ? '—'
                                    : '${gain > 0 ? '↑' : '↓'}${gain.abs()}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  height: 1.5,
                                  color: colors.mutedForeground,
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
          ),
        ),
      ),
    );
  }
}
