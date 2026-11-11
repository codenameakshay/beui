/// Donut chart with linked center readout and interactive legend.
library;

import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
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
    String? label,
    String? name,
    required this.value,
    this.color,
    this.description,
  }) : label = label ?? name ?? id,
       name = name;

  /// Stable identity.
  final String id;

  /// Legend label.
  final String label;

  /// Source-compatible name. If both [label] and [name] are set, [name] wins.
  final String? name;

  /// Display name, preferring the source field over the legacy Flutter field.
  String get displayName => name ?? label;

  /// Nonnegative amount.
  final double value;

  /// Optional CSS color override.
  final String? color;

  /// Extra accessible detail.
  final String? description;
}

/// A segment after the source model has assigned its share and static arc.
@immutable
class BeuiPlacedDonutSegment {
  /// Creates a placed segment for renderer callbacks.
  const BeuiPlacedDonutSegment({
    required this.segment,
    required this.share,
    required this.startDegrees,
    required this.endDegrees,
    required this.radius,
    required this.single,
  });

  /// Original segment data.
  final BeuiDonutSegment segment;

  /// Fraction of the valid positive total, from zero to one.
  final double share;

  /// Start of the static arc after gap and round-cap insets.
  final double startDegrees;

  /// End of the static arc after gap and round-cap insets.
  final double endDegrees;

  /// Centerline radius in the source 200 by 200 viewBox.
  final double radius;

  /// Whether this is the only valid segment and therefore a full ring.
  final bool single;

  /// Stable identity.
  String get id => segment.id;

  /// Source display name, with legacy label fallback.
  String get name => segment.displayName;

  /// Segment amount.
  double get value => segment.value;

  /// Segment color override.
  String? get color => segment.color;

  /// Extra accessible detail.
  String? get description => segment.description;

  /// A fresh centerline path in the 200 by 200 viewBox.
  ///
  /// A new path is returned for each access so renderer mutations cannot
  /// change later paints or hit testing.
  Path get path {
    final result = Path();
    if (single) {
      result.addOval(
        Rect.fromCircle(center: const Offset(100, 100), radius: radius),
      );
      return result;
    }
    final start = _donutPoint(radius, startDegrees);
    final end = _donutPoint(radius, endDegrees);
    result
      ..moveTo(start.dx, start.dy)
      ..arcToPoint(
        end,
        radius: Radius.circular(radius),
        clockwise: true,
        largeArc: endDegrees - startDegrees > 180,
      );
    return result;
  }
}

/// Source-derived static donut geometry and round-cap hit ownership.
@immutable
class BeuiDonutGeometry {
  /// Builds clockwise arcs in source paint order.
  factory BeuiDonutGeometry.build(
    List<BeuiDonutSegment> segments, {
    double thickness = 22,
    double gap = 3,
  }) {
    final safeThickness = thickness.isFinite
        ? thickness.clamp(0.0, 184.0)
        : 22.0;
    final radius = 100 - safeThickness / 2 - 8;
    final valid = segments
        .where((segment) => segment.value.isFinite && segment.value > 0)
        .toList(growable: false);
    final total = valid.fold<double>(0, (sum, segment) => sum + segment.value);
    if (valid.isEmpty || !total.isFinite || total <= 0 || radius <= 0) {
      return BeuiDonutGeometry._(
        placed: const [],
        total: total.isFinite ? total : 0,
        radius: radius,
        thickness: safeThickness,
        gap: gap.isFinite ? gap : 0,
      );
    }
    final safeGap = gap.isFinite ? gap : 0.0;
    final capDegrees = (safeThickness / 2 / radius) * (180 / math.pi);
    final single = valid.length == 1;
    var cursor = 0.0;
    final placed = <BeuiPlacedDonutSegment>[];
    for (final segment in valid) {
      final sweep = segment.value / total * 360;
      final inset = single ? 0.0 : safeGap / 2 + capDegrees;
      final start = cursor + inset;
      final end = math.max(start + .01, cursor + sweep - inset);
      placed.add(
        BeuiPlacedDonutSegment(
          segment: segment,
          share: segment.value / total,
          startDegrees: start,
          endDegrees: end,
          radius: radius,
          single: single,
        ),
      );
      cursor += sweep;
    }
    return BeuiDonutGeometry._(
      placed: List.unmodifiable(placed),
      total: total,
      radius: radius,
      thickness: safeThickness,
      gap: safeGap,
    );
  }

  const BeuiDonutGeometry._({
    required this.placed,
    required this.total,
    required this.radius,
    required this.thickness,
    required this.gap,
  });

  /// Valid positive segments in source SVG paint order.
  final List<BeuiPlacedDonutSegment> placed;

  /// Sum of valid segment values.
  final double total;

  /// Static centerline radius.
  final double radius;

  /// Sanitized ring thickness.
  final double thickness;

  /// Sanitized gap in degrees.
  final double gap;

  /// Returns the topmost hit segment for a point in the 200 by 200 viewBox.
  /// Hit strokes use `thickness + 8`; reverse iteration matches SVG paint order
  /// when neighboring round caps overlap.
  String? hitTest(Offset point) {
    if (placed.isEmpty || !point.dx.isFinite || !point.dy.isFinite) return null;
    final dx = point.dx - 100;
    final dy = point.dy - 100;
    final distance = math.sqrt(dx * dx + dy * dy);
    final angle = (math.atan2(dx, -dy) * 180 / math.pi + 360) % 360;
    final hitRadius = thickness / 2 + 4;
    for (final item in placed.reversed) {
      if (item.single) {
        if ((distance - radius).abs() <= hitRadius) return item.id;
        continue;
      }
      final start = item.startDegrees;
      final end = item.endDegrees;
      final sweep = end - start;
      final relative = (angle - start + 360) % 360;
      final inside = relative <= sweep;
      if (inside) {
        if ((distance - radius).abs() <= hitRadius) return item.id;
        continue;
      }
      final startPoint = _donutPoint(radius, start);
      final endPoint = _donutPoint(radius, end);
      final startDistance = (point - startPoint).distance;
      final endDistance = (point - endPoint).distance;
      if (math.min(startDistance, endDistance) <= hitRadius) return item.id;
    }
    return null;
  }
}

Offset _donutPoint(double radius, double degrees) {
  final radians = degrees * math.pi / 180;
  return Offset(
    100 + radius * math.sin(radians),
    100 - radius * math.cos(radians),
  );
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
    this.controlActiveId = false,
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

  /// Treat [activeId], including explicit `null`, as externally owned.
  ///
  /// A non-null [activeId] remains controlled for compatibility when this is
  /// false. Set this to true to control the empty state explicitly.
  final bool controlActiveId;

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

class _BeuiDonutChartState extends State<BeuiDonutChart> {
  final _legendFocus = <String, FocusNode>{};
  final _spaceArmed = <String>{};
  final _focusVisible = <String>{};
  bool _pointerInteraction = false;

  FocusNode focusFor(String id) => _legendFocus.putIfAbsent(id, () {
    final focus = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          _pointerInteraction = false;
          if (node.hasFocus) setFocusVisible(id, true);
        }
        if (event is KeyUpEvent &&
            event.logicalKey == LogicalKeyboardKey.space &&
            _spaceArmed.remove(id)) {
          widget.onSelect?.call(id);
          return KeyEventResult.handled;
        }
        if (event is KeyUpEvent) {
          _spaceArmed.remove(id);
        }
        return KeyEventResult.ignored;
      },
    );
    focus.addListener(() {
      if (focus.hasFocus) {
        setActiveId(id);
      } else {
        _spaceArmed.remove(id);
        setFocusVisible(id, false);
        if (activeId == id &&
            !_legendFocus.values.any((node) => node.hasFocus)) {
          setActiveId(null);
        }
      }
    });
    return focus;
  });

  void setFocusVisible(String id, bool visible) {
    final changed = visible ? _focusVisible.add(id) : _focusVisible.remove(id);
    if (changed && mounted) setState(() {});
  }

  void notePointerInteraction() {
    _pointerInteraction = true;
    if (_focusVisible.isNotEmpty) {
      _focusVisible.clear();
      if (mounted) setState(() {});
    }
  }

  String? _internalActiveId;

  bool get _activeControlled =>
      widget.controlActiveId || widget.activeId != null;

  String? get activeId {
    final id = _activeControlled ? widget.activeId : _internalActiveId;
    return id != null && geometry.placed.any((segment) => segment.id == id)
        ? id
        : null;
  }

  String? get selectedId =>
      widget.selectedId != null &&
          geometry.placed.any((segment) => segment.id == widget.selectedId)
      ? widget.selectedId
      : null;

  BeuiDonutGeometry get geometry => BeuiDonutGeometry.build(
    widget.segments,
    thickness: widget.thickness,
    gap: widget.gap,
  );

  String Function(double) get format =>
      widget.formatValue ??
      (value) => beuiChartFormatNumber(value, maximumFractionDigits: 3);

  void setActiveId(String? id) {
    final validId =
        id != null && geometry.placed.any((segment) => segment.id == id)
        ? id
        : null;
    if (!_activeControlled && _internalActiveId != validId) {
      setState(() => _internalActiveId = validId);
    }
    widget.onActiveChange?.call(validId);
  }

  @override
  void didUpdateWidget(covariant BeuiDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.segments.map((segment) => segment.id).toSet();
    for (final id
        in _legendFocus.keys.where((id) => !ids.contains(id)).toList()) {
      _legendFocus.remove(id)!.dispose();
      _spaceArmed.remove(id);
      _focusVisible.remove(id);
    }
  }

  @override
  void initState() {
    super.initState();
    _internalActiveId = widget.defaultActiveId;
  }

  @override
  void dispose() {
    for (final focus in _legendFocus.values) {
      focus.dispose();
    }
    _spaceArmed.clear();
    _focusVisible.clear();
    super.dispose();
  }

  double get total => geometry.total;

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

/// Read-only source-facing view of the nearest donut chart's current model.
@immutable
class BeuiDonutModel {
  const BeuiDonutModel._({
    required this.placed,
    required this.total,
    required this.activeId,
    required this.selectedId,
    required this.formatValue,
    required this.setActive,
  });

  /// Valid segments with their share, path, and static geometry.
  final List<BeuiPlacedDonutSegment> placed;

  /// Sum of valid positive segment values.
  final double total;

  /// Current highlighted segment, if valid.
  final String? activeId;

  /// Current selected segment, if valid.
  final String? selectedId;

  /// Formatter used by the chart's built-in renderers.
  final String Function(double value) formatValue;

  /// Requests a highlighted segment change and notifies the owner.
  final ValueChanged<String?> setActive;
}

/// Access the current donut model from a descendant of [BeuiDonutChart].
class BeuiDonutChartScope {
  /// Returns a typed view backed by the existing chart state owner.
  static BeuiDonutModel of(BuildContext context) {
    final state = _DonutScope.of(context);
    return BeuiDonutModel._(
      placed: state.geometry.placed,
      total: state.total,
      activeId: state.activeId,
      selectedId: state.selectedId,
      formatValue: state.format,
      setActive: state.setActiveId,
    );
  }
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
  bool _entryComplete = false;
  Timer? _entryTimer;
  String? _hoveredHitId;

  void _showOnce() {
    if (_shown) return;
    setState(() => _shown = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _entryComplete = true;
    } else {
      _entryTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _entryComplete = true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown && Scrollable.maybeOf(context) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOnce();
      });
    }
  }

  @override
  void onScrollGeometryChanged() {
    if (!_shown && (visibleFraction ?? 0) >= .4) _showOnce();
  }

  @override
  void dispose() {
    _entryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _DonutScope.of(context);
    final colors = BeuiColors.resolve(context);
    final geometry = state.geometry;
    final segments = geometry.placed.map((placed) => placed.segment).toList();
    final total = geometry.total;
    void activateAt(Offset localPosition) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null ||
          total <= 0 ||
          (!_shown && !MediaQuery.disableAnimationsOf(context))) {
        return;
      }
      final scale = math.min(box.size.width, box.size.height) / 200;
      if (scale <= 0) return;
      final center = box.size.center(Offset.zero);
      final point = (localPosition - center) / scale + const Offset(100, 100);
      final nextId = geometry.hitTest(point);
      if (nextId == _hoveredHitId) return;
      if (_hoveredHitId != null) state.setActiveId(null);
      _hoveredHitId = nextId;
      if (nextId != null) state.setActiveId(nextId);
    }

    return Semantics(
      key: const ValueKey('donut-plot-coordinate-space'),
      image: true,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DonutTrack(
                thickness: geometry.thickness,
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
                                    delay:
                                        MediaQuery.disableAnimationsOf(
                                              context,
                                            ) ||
                                            _entryComplete
                                        ? Duration.zero
                                        : Duration(milliseconds: 150 + i * 60),
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
                                                  placed: geometry.placed[i],
                                                  segmentIndex: i,
                                                  thickness: geometry.thickness,
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
              onExit: (_) {
                if (_hoveredHitId != null) state.setActiveId(null);
                _hoveredHitId = null;
              },
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Center live region showing the total or active segment.
typedef BeuiDonutCenterBuilder =
    Widget Function(
      BuildContext context,
      BeuiPlacedDonutSegment? segment,
      double total,
    );

/// Renders a custom legend value or detail row for one placed segment.
typedef BeuiDonutLegendBuilder =
    Widget Function(BuildContext context, BeuiPlacedDonutSegment segment);

class BeuiDonutCenter extends StatefulWidget {
  /// Creates the center readout.
  const BeuiDonutCenter({
    super.key,
    this.totalLabel = 'Total',
    this.totalCaption,
    this.builder,
  });

  /// Caption used when no segment is active.
  final String totalLabel;

  /// Optional composed caption used instead of [totalLabel] when total is shown.
  ///
  /// This takes precedence over [totalLabel] when both are provided.
  final Widget? totalCaption;

  /// Replaces the default readout with content derived from the active segment.
  final BeuiDonutCenterBuilder? builder;

  @override
  State<BeuiDonutCenter> createState() => _BeuiDonutCenterState();
}

class _BeuiDonutCenterState extends State<BeuiDonutCenter> {
  double? _previous;
  BeuiDigitSwapDirection _direction = BeuiDigitSwapDirection.up;

  @override
  Widget build(BuildContext context) {
    final state = _DonutScope.of(context);
    final geometry = state.geometry;
    final active = geometry.placed
        .where((s) => s.id == state.activeId)
        .firstOrNull;
    final value = active?.value ?? state.total;
    if (widget.builder case final builder?) {
      return _DonutCenterWidth(
        child: Semantics(
          liveRegion: true,
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            child: builder(context, active, geometry.total),
          ),
        ),
      );
    }
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
    return _DonutCenterWidth(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Source caps the caption, but its inline-flex digits never wrap.
            OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              fit: OverflowBoxFit.deferToChild,
              child: BeuiDigitSwap(
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
                            child:
                                widget.totalCaption ??
                                Text(widget.totalLabel, style: captionStyle),
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
                                              .indexOf(active.segment) %
                                          beuiChartPalette.length],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${active.name} · ${state.total <= 0 ? '0.0%' : beuiChartPercent(active.value / state.total)}',
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

class _DonutCenterWidth extends StatelessWidget {
  const _DonutCenterWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * .56),
        child: DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          child: child,
        ),
      ),
    ),
  );
}

class _DonutActivateIntent extends Intent {
  const _DonutActivateIntent();
}

class _DonutSpaceDownIntent extends Intent {
  const _DonutSpaceDownIntent();
}

class _DonutMoveIntent extends Intent {
  const _DonutMoveIntent(this.delta);
  final int delta;
}

/// Interactive legend buttons with arrow-key navigation.
class BeuiDonutLegend extends StatelessWidget {
  /// Creates the legend.
  const BeuiDonutLegend({super.key, this.renderDetail, this.renderValue});

  /// Replaces the detail line below each row.
  final BeuiDonutLegendBuilder? renderDetail;

  /// Replaces the trailing percentage and formatted value.
  final BeuiDonutLegendBuilder? renderValue;

  @override
  Widget build(BuildContext context) {
    final state = _DonutScope.of(context);
    final colors = BeuiColors.resolve(context);
    final placed = state.geometry.placed;
    final segments = placed.map((item) => item.segment).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < segments.length; i++)
          Builder(
            builder: (context) {
              final segment = segments[i];
              final placedSegment = placed[i];
              final active = state.activeId == segment.id;
              final selected = state.selectedId == segment.id;
              final color = beuiChartColor(
                segment.color,
                colors,
                fallback: beuiChartPalette[i % beuiChartPalette.length],
              );
              final description = segment.description == null
                  ? ''
                  : ', ${segment.description!}';
              final focus = state.focusFor(segment.id);
              final focusVisible = state._focusVisible.contains(segment.id);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == segments.length - 1 ? 0 : 4,
                ),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label:
                      '${segment.displayName}: ${state.format(segment.value)}$description',
                  child: MouseRegion(
                    onEnter: (_) => state.setActiveId(segment.id),
                    onExit: (_) => state.setActiveId(null),
                    child: FocusableActionDetector(
                      focusNode: focus,
                      onShowFocusHighlight: (visible) => state.setFocusVisible(
                        segment.id,
                        visible && !state._pointerInteraction,
                      ),
                      key: ValueKey('donut-legend-${segment.id}'),
                      shortcuts: {
                        SingleActivator(LogicalKeyboardKey.space):
                            const _DonutSpaceDownIntent(),
                        SingleActivator(
                          LogicalKeyboardKey.enter,
                          includeRepeats: true,
                        ): const _DonutActivateIntent(),
                        SingleActivator(LogicalKeyboardKey.arrowDown):
                            const _DonutMoveIntent(1),
                        SingleActivator(LogicalKeyboardKey.arrowUp):
                            const _DonutMoveIntent(-1),
                      },
                      actions: {
                        _DonutSpaceDownIntent:
                            CallbackAction<_DonutSpaceDownIntent>(
                              onInvoke: (_) {
                                state._spaceArmed.add(segment.id);
                                return null;
                              },
                            ),
                        _DonutActivateIntent:
                            CallbackAction<_DonutActivateIntent>(
                              onInvoke: (_) {
                                focus.requestFocus();
                                state.widget.onSelect?.call(segment.id);
                                return null;
                              },
                            ),
                        _DonutMoveIntent: CallbackAction<_DonutMoveIntent>(
                          onInvoke: (intent) {
                            state
                                .focusFor(
                                  segments[(i +
                                              intent.delta +
                                              segments.length) %
                                          segments.length]
                                      .id,
                                )
                                .requestFocus();
                            return null;
                          },
                        ),
                      },
                      child: Semantics(
                        button: true,
                        enabled: true,
                        selected: selected,
                        label:
                            '${segment.displayName}: ${state.format(segment.value)}$description',
                        onTap: () {
                          focus.requestFocus();
                          state.widget.onSelect?.call(segment.id);
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          excludeFromSemantics: true,
                          onTapDown: (_) => state.notePointerInteraction(),
                          onTap: () {
                            focus.requestFocus();
                            state.widget.onSelect?.call(segment.id);
                          },
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
                                        segment.displayName,
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
                                    if (renderValue != null)
                                      renderValue!(context, placedSegment)
                                    else ...[
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
                                  ],
                                ),
                                if (renderDetail != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 22,
                                      top: 2,
                                    ),
                                    child: DefaultTextStyle(
                                      style: TextStyle(
                                        color: colors.mutedForeground,
                                        fontSize: 12,
                                      ),
                                      child: renderDetail!(
                                        context,
                                        placedSegment,
                                      ),
                                    ),
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
                                              widthFactor: share.clamp(
                                                0.0,
                                                1.0,
                                              ),
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
    final radius = (100 - thickness / 2 - 8) * scale;
    if (radius <= 0) return;
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
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
    required this.placed,
    required this.segmentIndex,
    required this.thickness,
    required this.colors,
  });
  final BeuiPlacedDonutSegment placed;
  final double thickness;
  final int segmentIndex;
  final BeuiColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 200;
    final center = size.center(Offset.zero);
    final color = beuiChartColor(
      placed.color,
      colors,
      fallback: beuiChartPalette[segmentIndex % beuiChartPalette.length],
    );
    canvas
      ..save()
      ..translate(center.dx - 100 * scale, center.dy - 100 * scale)
      ..scale(scale);
    canvas.drawPath(
      placed.path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.placed != placed ||
      old.thickness != thickness ||
      old.colors != colors;
}
