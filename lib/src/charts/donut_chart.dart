/// Donut chart with linked center readout and interactive legend.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart';

/// A labeled donut slice.
@immutable
class BeuiDonutSegment {
  /// Creates a segment.
  const BeuiDonutSegment({
    required this.id,
    required this.label,
    required this.value,
    this.color,
    this.description,
  });

  /// Stable identity.
  final String id;

  /// Legend label.
  final String label;

  /// Nonnegative amount.
  final double value;

  /// Optional CSS color override.
  final String? color;

  /// Extra accessible detail.
  final String? description;
}

/// Composable donut chart root.
class BeuiDonutChart extends StatefulWidget {
  /// Creates a donut chart.
  const BeuiDonutChart({
    required this.segments,
    super.key,
    this.thickness = 22,
    this.gap = 3,
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.onSelect,
    this.selectedId,
    this.formatValue,
    this.label = 'Donut chart',
    this.child,
  });

  /// Ordered ring segments.
  final List<BeuiDonutSegment> segments;

  /// Ring width in viewBox units.
  final double thickness;

  /// Gap in degrees between slices.
  final double gap;

  /// Controlled highlighted segment.
  final String? activeId;

  /// Initial highlighted segment when uncontrolled.
  final String? defaultActiveId;

  /// Highlight callback.
  final ValueChanged<String?>? onActiveChange;

  /// Legend selection callback.
  final ValueChanged<String>? onSelect;

  /// Selected legend id.
  final String? selectedId;

  /// Value formatter.
  final String Function(double value)? formatValue;

  /// Accessible chart name.
  final String label;

  /// Custom composition.
  final Widget? child;
  @override
  State<BeuiDonutChart> createState() => _BeuiDonutChartState();
}

class _BeuiDonutChartState extends State<BeuiDonutChart>
    with BeuiChartActiveState<BeuiDonutChart> {
  @override
  String? get widgetActiveId => widget.activeId;
  @override
  String? get widgetDefaultActiveId => widget.defaultActiveId;
  @override
  ValueChanged<String?>? get widgetOnActiveChange => widget.onActiveChange;
  @override
  Iterable<String> get knownIds => widget.segments.map((s) => s.id);
  double get total => widget.segments
      .where((s) => s.value.isFinite && s.value > 0)
      .fold(0, (sum, s) => sum + s.value);
  String Function(double) get format =>
      widget.formatValue ?? (v) => beuiChartFormatNumber(v);
  @override
  void initState() {
    super.initState();
    initActive();
  }

  @override
  Widget build(BuildContext context) => _DonutScope(
    state: this,
    child: BeuiChartFrame(
      label: widget.label,
      child:
          widget.child ??
          const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 200, height: 200, child: BeuiDonutPlot()),
              SizedBox(width: 20),
              Expanded(child: BeuiDonutLegend()),
            ],
          ),
    ),
  );
}

class _DonutScope extends InheritedWidget {
  const _DonutScope({required this.state, required super.child});
  final _BeuiDonutChartState state;
  static _BeuiDonutChartState of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<_DonutScope>();
    assert(s != null, 'Donut parts must be inside BeuiDonutChart.');
    return s!.state;
  }

  @override
  bool updateShouldNotify(_DonutScope old) => true;
}

/// Ring plot with an optional center overlay.
class BeuiDonutPlot extends StatelessWidget {
  /// Creates a 200 by 200 ring plot.
  const BeuiDonutPlot({super.key, this.child});

  /// Center overlay.
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final state = _DonutScope.of(context);
    final colors = BeuiColors.resolve(context);
    final segments = state.widget.segments
        .where((s) => s.value.isFinite && s.value > 0)
        .toList();
    final total = state.total;
    void activateAt(Offset localPosition, {bool select = false}) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || total <= 0) return;
      final pos = localPosition - box.size.center(Offset.zero);
      final scale = math.min(box.size.width, box.size.height) / 200;
      final ringRadius = (100 - state.widget.thickness / 2 - 8) * scale;
      final distance = pos.distance;
      if ((distance - ringRadius).abs() >
          state.widget.thickness * scale / 2 + 3) {
        if (!select) state.setActiveId(null);
        return;
      }
      final angle = (math.atan2(pos.dx, -pos.dy) * 180 / math.pi + 360) % 360;
      var cursor = 0.0;
      for (final segment in segments) {
        final sweep = segment.value / total * 360;
        if (angle >= cursor && angle < cursor + sweep) {
          state.setActiveId(segment.id);
          if (select) state.widget.onSelect?.call(segment.id);
          return;
        }
        cursor += sweep;
      }
      if (!select) state.setActiveId(null);
    }

    return BeuiChartSpring(
      value: total,
      builder: (context, animatedTotal) => Semantics(
        image: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CustomPaint(
                painter: _DonutPainter(
                  segments: segments,
                  total: total,
                  sweepProgress: total <= 0
                      ? 1
                      : (animatedTotal / total).clamp(0.0, 1.0),
                  thickness: state.widget.thickness,
                  gap: state.widget.gap,
                  activeId: state.activeId,
                  colors: colors,
                ),
              ),
            ),
            if (child != null) SizedBox.expand(child: Center(child: child)),
            if (child == null) const BeuiDonutCenter(),
            Positioned.fill(
              child: MouseRegion(
                onHover: (event) => activateAt(event.localPosition),
                onExit: (_) => state.setActiveId(null),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (event) =>
                      activateAt(event.localPosition, select: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Center live region showing the total or active segment.
class BeuiDonutCenter extends StatelessWidget {
  /// Creates the center readout.
  const BeuiDonutCenter({super.key, this.totalLabel = 'Total'});

  /// Caption used when no segment is active.
  final String totalLabel;
  @override
  Widget build(BuildContext context) {
    final state = _DonutScope.of(context);
    final active = state.widget.segments
        .where((s) => s.id == state.activeId)
        .firstOrNull;
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeuiChartTicker(
            value: active?.value ?? state.total,
            format: (v) => state.format(v.toDouble()),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(
            height: 16,
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? const Duration(milliseconds: 120)
                    : const Duration(milliseconds: 220),
                switchInCurve: beuiEaseOut,
                switchOutCurve: beuiEaseOut,
                transitionBuilder: (child, animation) {
                  if (MediaQuery.disableAnimationsOf(context)) {
                    return FadeTransition(opacity: animation, child: child);
                  }
                  final isIncoming =
                      child.key == ValueKey(active?.id ?? 'total');
                  final offset = Tween<Offset>(
                    begin: Offset(0, isIncoming ? 1 : -1),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(position: offset, child: child);
                },
                child: SizedBox(
                  key: ValueKey(active?.id ?? 'total'),
                  height: 16,
                  child: active == null
                      ? Center(
                          child: Text(
                            totalLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BeuiChartSwatch(
                              color: beuiChartColor(
                                active.color,
                                BeuiColors.resolve(context),
                                fallback:
                                    beuiChartPalette[state.widget.segments
                                            .indexOf(active) %
                                        beuiChartPalette.length],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${active.label} · ${state.total <= 0 ? '0.0%' : beuiChartPercent(active.value / state.total)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive legend buttons with arrow-key navigation.
class BeuiDonutLegend extends StatelessWidget {
  /// Creates the legend.
  const BeuiDonutLegend({super.key});
  @override
  Widget build(BuildContext context) {
    final state = _DonutScope.of(context);
    final colors = BeuiColors.resolve(context);
    final segments = state.widget.segments
        .where((s) => s.value.isFinite && s.value > 0)
        .toList();
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
            segments.isEmpty) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        final index = segments.indexWhere((s) => s.id == state.activeId);
        if (key == LogicalKeyboardKey.escape) {
          state.setActiveId(null);
          return KeyEventResult.handled;
        }
        var next = index;
        if (key == LogicalKeyboardKey.home) {
          next = 0;
        } else if (key == LogicalKeyboardKey.end) {
          next = segments.length - 1;
        } else if (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowRight) {
          next = (index + 1).clamp(0, segments.length - 1);
        } else if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowLeft) {
          next = (index < 0 ? segments.length - 1 : index - 1).clamp(
            0,
            segments.length - 1,
          );
        } else {
          return KeyEventResult.ignored;
        }
        state.setActiveId(segments[next].id);
        return KeyEventResult.handled;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++)
            Builder(
              builder: (context) {
                final segment = segments[i];
                final active = state.activeId == segment.id;
                final selected = state.widget.selectedId == segment.id;
                final color = beuiChartColor(
                  segment.color,
                  colors,
                  fallback: beuiChartPalette[i % beuiChartPalette.length],
                );
                final description = segment.description == null
                    ? ''
                    : ', ${segment.description!}';
                return Semantics(
                  button: true,
                  selected: selected,
                  label:
                      '${segment.label}: ${state.format(segment.value)}$description',
                  child: MouseRegion(
                    onEnter: (_) => state.setActiveId(segment.id),
                    onExit: (_) => state.setActiveId(null),
                    child: Focus(
                      onFocusChange: (focused) =>
                          state.setActiveId(focused ? segment.id : null),
                      child: GestureDetector(
                        onTap: () {
                          state.setActiveId(active ? null : segment.id);
                          state.widget.onSelect?.call(segment.id);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? colors.muted.withValues(alpha: .35)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  BeuiChartSwatch(color: color),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      segment.label,
                                      style: TextStyle(
                                        fontWeight: active
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    state.total <= 0
                                        ? '0.0%'
                                        : beuiChartPercent(
                                            segment.value / state.total,
                                          ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: colors.foreground,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    state.format(segment.value),
                                    style: TextStyle(
                                      color: colors.mutedForeground,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: BeuiChartSpring(
                                  value: state.total <= 0
                                      ? 0
                                      : segment.value / state.total,
                                  builder: (context, share) =>
                                      FractionallySizedBox(
                                        widthFactor: share.clamp(0.0, 1.0),
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
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
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.total,
    required this.sweepProgress,
    required this.thickness,
    required this.gap,
    required this.activeId,
    required this.colors,
  });
  final List<BeuiDonutSegment> segments;
  final double total, thickness, gap;
  final double sweepProgress;
  final String? activeId;
  final BeuiColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 200;
    final center = size.center(Offset.zero);
    final radius = (100 - thickness / 2 - 8) * scale;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = colors.muted.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness * scale,
    );
    var cursor = -math.pi / 2;
    var remaining = math.pi * 2 * sweepProgress;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final sweep = total <= 0 ? 0.0 : s.value / total * math.pi * 2;
      final visibleSweep = math.min(sweep, math.max(0.0, remaining));
      if (visibleSweep <= 0) break;
      final g = gap * math.pi / 180;
      final start = cursor + (segments.length == 1 ? 0 : g / 2);
      final span = math.max(
        .001,
        visibleSweep - (segments.length == 1 ? 0 : g),
      );
      final color = beuiChartColor(
        s.color,
        colors,
        fallback: beuiChartPalette[i % beuiChartPalette.length],
      );
      final active = activeId == s.id;
      final r = radius * (active ? 1.05 : 1);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        math.min(span, math.pi * 2 - .001),
        false,
        Paint()
          ..color = color.withValues(alpha: activeId == null || active ? 1 : .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness * scale * (active ? 1.05 : 1)
          ..strokeCap = StrokeCap.round,
      );
      cursor += sweep;
      remaining -= visibleSweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments ||
      old.activeId != activeId ||
      old.thickness != thickness ||
      old.gap != gap ||
      old.sweepProgress != sweepProgress;
}
