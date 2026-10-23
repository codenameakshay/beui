/// Donut chart with linked center readout and interactive legend.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '../motion/_scroll_geometry.dart';
import '../motion/digit_swap.dart';
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
  final _legendFocus = <String, FocusNode>{};
  FocusNode focusFor(String id) => _legendFocus.putIfAbsent(id, FocusNode.new);

  @override
  void didUpdateWidget(covariant BeuiDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.segments.map((segment) => segment.id).toSet();
    for (final id
        in _legendFocus.keys.where((id) => !ids.contains(id)).toList()) {
      _legendFocus.remove(id)!.dispose();
    }
  }

  @override
  void dispose() {
    for (final focus in _legendFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

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
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(256.0, constraints.maxWidth);
              final plot = SizedBox(
                width: size,
                height: size,
                child: const BeuiDonutPlot(),
              );
              return MediaQuery.sizeOf(context).width < 640
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        plot,
                        const SizedBox(height: 24),
                        const BeuiDonutLegend(),
                      ],
                    )
                  : Row(
                      children: [
                        plot,
                        const SizedBox(width: 24),
                        const Expanded(child: BeuiDonutLegend()),
                      ],
                    );
            },
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
class BeuiDonutPlot extends StatefulWidget {
  /// Creates a 200 by 200 ring plot.
  const BeuiDonutPlot({super.key, this.child});

  /// Center overlay.
  final Widget? child;
  @override
  State<BeuiDonutPlot> createState() => _BeuiDonutPlotState();
}

class _BeuiDonutPlotState extends State<BeuiDonutPlot>
    with ScrollGeometryMixin {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown && Scrollable.maybeOf(context) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_shown) setState(() => _shown = true);
      });
    }
  }

  @override
  void onScrollGeometryChanged() {
    if (!_shown && (visibleFraction ?? 0) >= .4) setState(() => _shown = true);
  }

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

    return Semantics(
      image: true,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DonutTrack(
                thickness: state.widget.thickness,
                color: colors.muted.withValues(alpha: .6),
              ),
            ),
          ),
          Positioned.fill(
            child: !_shown && !MediaQuery.disableAnimationsOf(context)
                ? const SizedBox.expand()
                : BeuiChartTween(
                    key: const ValueKey('donut-ring-entrance'),
                    from: 0,
                    value: 1,
                    duration: const Duration(milliseconds: 900),
                    isMovement: true,
                    builder: (context, entrance) => Opacity(
                      opacity: entrance.clamp(0, 1),
                      child: Transform.rotate(
                        angle: -math.pi / 2 * (1 - entrance),
                        child: Transform.scale(
                          scale: .88 + .12 * entrance,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (var i = 0; i < segments.length; i++)
                                Positioned.fill(
                                  key: ValueKey(segments[i].id),
                                  child: BeuiChartTween(
                                    from: 0,
                                    value:
                                        state.activeId == null ||
                                            state.activeId == segments[i].id
                                        ? 1
                                        : .3,
                                    duration: const Duration(milliseconds: 400),
                                    delay: Duration(milliseconds: 150 + i * 60),
                                    snapWhenReduced: true,
                                    builder: (context, opacity) => Opacity(
                                      opacity: opacity.clamp(0, 1),
                                      child: BeuiChartSpring(
                                        value: state.activeId == segments[i].id
                                            ? 1.05
                                            : 1,
                                        builder: (context, scale) =>
                                            Transform.scale(
                                              scale: scale,
                                              child: CustomPaint(
                                                painter: _DonutPainter(
                                                  segments: segments,
                                                  total: total,
                                                  segmentIndex: i,
                                                  thickness:
                                                      state.widget.thickness,
                                                  gap: state.widget.gap,
                                                  colors: colors,
                                                ),
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
          ),
          if (widget.child != null)
            SizedBox.expand(child: Center(child: widget.child)),
          if (widget.child == null) const BeuiDonutCenter(),
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
    );
  }
}

/// Center live region showing the total or active segment.
class BeuiDonutCenter extends StatefulWidget {
  /// Creates the center readout.
  const BeuiDonutCenter({super.key, this.totalLabel = 'Total'});

  /// Caption used when no segment is active.
  final String totalLabel;

  @override
  State<BeuiDonutCenter> createState() => _BeuiDonutCenterState();
}

class _BeuiDonutCenterState extends State<BeuiDonutCenter> {
  double? _previous;
  BeuiDigitSwapDirection _direction = BeuiDigitSwapDirection.up;

  @override
  Widget build(BuildContext context) {
    final state = _DonutScope.of(context);
    final active = state.widget.segments
        .where((s) => s.id == state.activeId)
        .firstOrNull;
    final value = active?.value ?? state.total;
    if (_previous != null && _previous != value) {
      _direction = value > _previous!
          ? BeuiDigitSwapDirection.up
          : BeuiDigitSwapDirection.down;
    }
    _previous = value;
    final captionStyle = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      color: BeuiColors.resolve(context).mutedForeground,
    );
    return FractionallySizedBox(
      widthFactor: .56,
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiDigitSwap(
              value: state.format(value),
              direction: _direction,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: -.6,
                color: BeuiColors.resolve(context).foreground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
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
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: SizedBox(
                    key: ValueKey(active?.id ?? 'total'),
                    height: 16,
                    child: active == null
                        ? Center(
                            child: Text(widget.totalLabel, style: captionStyle),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BeuiChartSwatch(
                                size: 8,
                                color: beuiChartColor(
                                  active.color,
                                  BeuiColors.resolve(context),
                                  fallback:
                                      beuiChartPalette[state.widget.segments
                                              .indexOf(active) %
                                          beuiChartPalette.length],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${active.label} · ${state.total <= 0 ? '0.0%' : beuiChartPercent(active.value / state.total)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: captionStyle,
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
    return Column(
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
              final focus = state.focusFor(segment.id);
              final focusVisible =
                  focus.hasFocus &&
                  FocusManager.instance.highlightMode ==
                      FocusHighlightMode.traditional;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == segments.length - 1 ? 0 : 4,
                ),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label:
                      '${segment.label}: ${state.format(segment.value)}$description',
                  child: MouseRegion(
                    onEnter: (_) => state.setActiveId(segment.id),
                    onExit: (_) => state.setActiveId(null),
                    child: Focus(
                      canRequestFocus: false,
                      onFocusChange: (focused) {
                        if (focused) {
                          state.setActiveId(segment.id);
                        } else if (state.activeId == segment.id) {
                          state.setActiveId(null);
                        }
                      },
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent &&
                            event is! KeyRepeatEvent) {
                          return KeyEventResult.ignored;
                        }
                        final step =
                            event.logicalKey == LogicalKeyboardKey.arrowDown
                            ? 1
                            : event.logicalKey == LogicalKeyboardKey.arrowUp
                            ? -1
                            : 0;
                        if (step == 0) return KeyEventResult.ignored;
                        state
                            .focusFor(
                              segments[(i + step + segments.length) %
                                      segments.length]
                                  .id,
                            )
                            .requestFocus();
                        return KeyEventResult.handled;
                      },
                      child: TextButton(
                        focusNode: focus,
                        key: ValueKey('donut-legend-${segment.id}'),
                        onPressed: () {
                          focus.requestFocus();
                          state.widget.onSelect?.call(segment.id);
                        },
                        style: TextButton.styleFrom(
                          overlayColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active ? colors.muted : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              if (focusVisible || selected)
                                BoxShadow(
                                  color: focusVisible
                                      ? colors.ring
                                      : colors.border,
                                  spreadRadius: focusVisible ? 2 : 1,
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  BeuiChartSwatch(color: color, size: 10),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      segment.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        height: 20 / 14,
                                        color: colors.foreground,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                      fontSize: 14,
                                      height: 20 / 14,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      color: colors.foreground,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    state.format(segment.value),
                                    style: TextStyle(
                                      color: colors.mutedForeground,
                                      fontSize: 14,
                                      height: 20 / 14,
                                      fontWeight: FontWeight.w400,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 22),
                                child: Container(
                                  height: 4,
                                  clipBehavior: Clip.hardEdge,
                                  decoration: BoxDecoration(
                                    color: colors.muted,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: BeuiChartTween(
                                      from: 0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      delay: Duration(
                                        milliseconds: 200 + i * 60,
                                      ),
                                      motion: beuiSpringLayout,
                                      isMovement: true,
                                      value: state.total <= 0
                                          ? 0
                                          : segment.value / state.total,
                                      builder: (context, share) =>
                                          FractionallySizedBox(
                                            widthFactor: share.clamp(0.0, 1.0),
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
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
                ),
              );
            },
          ),
      ],
    );
  }
}

class _DonutTrack extends CustomPainter {
  const _DonutTrack({required this.thickness, required this.color});
  final double thickness;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 200;
    canvas.drawCircle(
      size.center(Offset.zero),
      (100 - thickness / 2 - 8) * scale,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness * scale,
    );
  }

  @override
  bool shouldRepaint(_DonutTrack old) =>
      old.thickness != thickness || old.color != color;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.segments,
    required this.total,
    required this.segmentIndex,
    required this.thickness,
    required this.gap,
    required this.colors,
  });
  final List<BeuiDonutSegment> segments;
  final double total, thickness, gap;
  final int segmentIndex;
  final BeuiColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 200;
    final center = size.center(Offset.zero);
    final radius = (100 - thickness / 2 - 8) * scale;
    final segment = segments[segmentIndex];
    final sweep = segment.value / total * math.pi * 2;
    final cursor = segments
        .take(segmentIndex)
        .fold<double>(
          -math.pi / 2,
          (a, s) => a + s.value / total * math.pi * 2,
        );
    final inset = segments.length == 1
        ? 0.0
        : gap * math.pi / 360 + thickness * scale / 2 / radius;
    final color = beuiChartColor(
      segment.color,
      colors,
      fallback: beuiChartPalette[segmentIndex % beuiChartPalette.length],
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      cursor + inset,
      segments.length == 1
          ? math.pi * 2
          : math.max(.01 * math.pi / 180, sweep - inset * 2),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments ||
      old.total != total ||
      old.thickness != thickness ||
      old.gap != gap ||
      old.colors != colors;
}
