/// Historical prices with high, mean and low analyst projections.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';

import '../motion/number_ticker.dart';
import '../motion/_engine.dart' show SpringMotion;
import '../theme/beui_colors.dart';
import '../theme/beui_text_theme.dart';
import '../tokens/motion.dart';
import '_shared.dart';

/// One analyst price target.
@immutable
class BeuiPriceTarget {
  /// Creates a target.
  const BeuiPriceTarget({
    required this.key,
    required this.price,
    this.analysts = 0,
    this.color,
  });

  /// Target label, e.g. High, Mean, or Low.
  final String key;

  /// Positive target price.
  final double price;

  /// Number of analysts contributing to the target.
  final int analysts;

  /// Optional CSS-style hex or beUI token.
  final String? color;
}

/// One dated historical price point.
@immutable
class BeuiPriceHistoryPoint {
  /// Creates a price point.
  const BeuiPriceHistoryPoint({required this.date, required this.price});

  /// ISO-8601 calendar date.
  final String date;

  /// Positive historical price.
  final double price;
}

/// Optional labels for the start, midpoint and projection horizon.
@immutable
class BeuiPriceTargetDates {
  /// Creates axis labels.
  const BeuiPriceTargetDates({this.start, this.mid, this.horizon});

  /// Label at the oldest history point.
  final String? start;

  /// Label near the history midpoint.
  final String? mid;

  /// Label at the forecast horizon.
  final String? horizon;
}

/// Active point in the history series or a selected analyst target.
@immutable
class BeuiPriceTargetFanActive {
  /// Selects a historical date.
  const BeuiPriceTargetFanActive.history(this.date)
    : type = 'history',
      key = null;

  /// Selects a target by key.
  const BeuiPriceTargetFanActive.target(this.key)
    : type = 'target',
      date = null;

  /// Kind of active value: `history` or `target`.
  final String type;

  /// Date for history selections.
  final String? date;

  /// Target key for target selections.
  final String? key;

  @override
  bool operator ==(Object other) =>
      other is BeuiPriceTargetFanActive &&
      other.type == type &&
      other.date == date &&
      other.key == key;

  @override
  int get hashCode => Object.hash(type, date, key);
}

/// One labeled row in a source-shaped price-target tooltip.
@immutable
class BeuiPriceTargetFanTooltipMetric {
  /// Creates a tooltip metric.
  const BeuiPriceTargetFanTooltipMetric({
    required this.label,
    required this.value,
  });

  /// Row label.
  final String label;

  /// Row value.
  final String value;
}

/// Optional source-shaped accent row in a target tooltip.
@immutable
class BeuiPriceTargetFanTooltipAccent {
  /// Creates a tooltip accent row.
  const BeuiPriceTargetFanTooltipAccent({
    required this.label,
    required this.value,
    required this.color,
  });

  /// Accent label.
  final String label;

  /// Accent value.
  final String value;

  /// Original target CSS color literal.
  final String color;
}

/// Source-derived content and plot anchor passed to a dynamic tooltip builder.
@immutable
class BeuiPriceTargetFanTooltipData {
  /// Creates a source-shaped tooltip description.
  const BeuiPriceTargetFanTooltipData({
    required this.title,
    required this.anchor,
    required this.metrics,
    this.accent,
  });

  /// Tooltip title.
  final String title;

  /// Anchor point in the 520×236 plot coordinate space.
  final Offset anchor;

  /// Ordered metric rows.
  final List<BeuiPriceTargetFanTooltipMetric> metrics;

  /// Optional target change row.
  final BeuiPriceTargetFanTooltipAccent? accent;
}

/// Data and interaction owner for a composable price-target fan.
class BeuiPriceTargetFan extends StatefulWidget {
  /// Creates a price-target fan.
  const BeuiPriceTargetFan({
    super.key,
    required this.current,
    required this.targets,
    this.dates = const BeuiPriceTargetDates(),
    this.history = const [],
    this.label = 'Price target · 12 months',
    this.active,
    this.activeIsControlled = false,
    this.defaultActive,
    this.onActiveChange,
    this.child,
  });

  /// Last traded price.
  final double current;

  /// High, mean, and low targets, in that order.
  final List<BeuiPriceTarget> targets;

  /// Axis labels.
  final BeuiPriceTargetDates dates;

  /// Historical samples, oldest first.
  final List<BeuiPriceHistoryPoint> history;

  /// Accessible chart name.
  final String label;

  /// Controlled active point.
  final BeuiPriceTargetFanActive? active;

  /// Treats [active] as controlled even when it is explicitly null.
  ///
  /// A non-null [active] is already controlled. Set this flag when the parent
  /// owns the empty selection and wants callbacks without internal mutation.
  final bool activeIsControlled;

  /// Initial active point for uncontrolled use.
  final BeuiPriceTargetFanActive? defaultActive;

  /// Reports changes to the active point.
  final ValueChanged<BeuiPriceTargetFanActive?>? onActiveChange;

  /// Custom composition. Defaults to header and plot.
  final Widget? child;

  @override
  State<BeuiPriceTargetFan> createState() => _BeuiPriceTargetFanState();
}

class _BeuiPriceTargetFanState extends State<BeuiPriceTargetFan>
    with BeuiChartActiveState<BeuiPriceTargetFan>, BeuiChartInspectorKeys {
  static const double width = 520;
  static const double height = 236;
  static const double left = 36;
  static const double right = 108;
  static const double top = 16;
  static const double bottom = 28;
  final _historyFocus = FocusNode();
  final _targetFocus = <String, FocusNode>{};
  PointerDeviceKind? _targetPointerKind;
  PointerDeviceKind? _historyPointerKind;
  bool _historyFocused = false;
  bool _historyFocusVisible = false;

  FocusNode focusFor(String key) =>
      _targetFocus.putIfAbsent(key, FocusNode.new);

  void clearBlurredInspection() {
    if (!_historyFocus.hasFocus &&
        !_targetFocus.values.any((focus) => focus.hasFocus)) {
      setActiveId(null);
    }
  }

  void _setHistoryFocus(bool focused) {
    if (_historyFocused == focused || !mounted) return;
    setState(() => _historyFocused = focused);
  }

  void _setHistoryFocusVisible(bool visible) {
    if (_historyFocusVisible == visible || !mounted) return;
    setState(() => _historyFocusVisible = visible);
  }

  void _setHistoryPointerKind(PointerDeviceKind kind) {
    _historyPointerKind = kind;
    _setHistoryFocusVisible(false);
  }

  @override
  void dispose() {
    _historyFocus.dispose();
    for (final focus in _targetFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  String? get widgetActiveId => _id(widget.active);
  @override
  String? get widgetDefaultActiveId => _id(widget.defaultActive);
  @override
  ValueChanged<String?>? get widgetOnActiveChange =>
      (id) => widget.onActiveChange?.call(_active(id));
  @override
  Iterable<String> get knownIds => inspectableIds;
  @override
  String? get activeId => widget.activeIsControlled || widget.active != null
      ? _id(widget.active)
      : super.activeId;
  @override
  List<String> get inspectableIds => [
    for (final point in widget.history) 'h:${point.date}',
    for (final target in widget.targets) 't:${target.key}',
  ];

  static String? _id(BeuiPriceTargetFanActive? active) => active == null
      ? null
      : active.type == 'history'
      ? 'h:${active.date}'
      : 't:${active.key}';
  BeuiPriceTargetFanActive? _active(String? id) {
    if (id == null) return null;
    if (id.startsWith('h:')) {
      return BeuiPriceTargetFanActive.history(id.substring(2));
    }
    if (id.startsWith('t:')) {
      return BeuiPriceTargetFanActive.target(id.substring(2));
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _validate(widget);
    initActive();
  }

  @override
  void didUpdateWidget(covariant BeuiPriceTargetFan oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validate(widget);
    final keys = widget.targets.map((target) => target.key).toSet();
    for (final key
        in _targetFocus.keys.where((key) => !keys.contains(key)).toList()) {
      _targetFocus.remove(key)!.dispose();
    }
  }

  void _validate(BeuiPriceTargetFan input) {
    if (!input.current.isFinite ||
        input.current <= 0 ||
        input.targets.length != 3 ||
        input.targets.any(
          (target) => !target.price.isFinite || target.price <= 0,
        ) ||
        input.targets.map((target) => target.key).toSet().length != 3) {
      throw ArgumentError(
        'BeuiPriceTargetFan requires exactly three unique positive targets.',
      );
    }
    int? previous;
    for (final point in input.history) {
      final isoDate = RegExp(
        r'^\d{4}-\d{2}-\d{2}(?:T.*(?:Z|[+-]\d{2}:\d{2}))?$',
      ).hasMatch(point.date);
      final timestamp = isoDate
          ? _tryHistoryDate(point.date)?.millisecondsSinceEpoch
          : null;
      if (!isoDate ||
          timestamp == null ||
          !point.price.isFinite ||
          point.price <= 0) {
        throw ArgumentError(
          'BeuiPriceTargetFan history requires positive prices and ISO dates.',
        );
      }
      if (previous != null && timestamp <= previous) {
        throw ArgumentError(
          'BeuiPriceTargetFan history dates must be strictly increasing.',
        );
      }
      previous = timestamp;
    }
  }

  @override
  void setActiveId(String? id) {
    if (widget.activeIsControlled || widget.active != null) {
      widget.onActiveChange?.call(_active(id));
      return;
    }
    super.setActiveId(id);
  }

  void _setHistoryHover(String date, bool hovered) {
    final id = 'h:$date';
    if (hovered) {
      setActiveId(id);
    } else {
      if (activeId == id) setActiveId(null);
    }
  }

  BeuiPriceTargetFanActive? get _resolvedActive =>
      inspectableIds.contains(activeId) ? _active(activeId) : null;
  BeuiPriceHistoryPoint? get _activeHistory {
    final active = _resolvedActive;
    if (active?.type != 'history') return null;
    for (final point in widget.history) {
      if (point.date == active!.date) return point;
    }
    return null;
  }

  List<double> get _domain {
    final prices = <double>[
      widget.current,
      ...widget.targets.map((t) => t.price),
      ...widget.history.map((p) => p.price),
    ];
    final minValue = prices.reduce(math.min);
    final maxValue = prices.reduce(math.max);
    final pad = math.max((maxValue - minValue) * .06, .5);
    return [minValue - pad, maxValue + pad];
  }

  double _y(double price) {
    final domain = _domain;
    return top +
        (domain[1] - price) / (domain[1] - domain[0]) * (height - top - bottom);
  }

  double get _nowX => left + (width - left - right) * .56;
  double _historyX(int index) {
    if (widget.history.length <= 1) return _nowX - 12;
    final first = _historyDate(
      widget.history.first.date,
    ).millisecondsSinceEpoch;
    final last = _historyDate(widget.history.last.date).millisecondsSinceEpoch;
    final time = _historyDate(
      widget.history[index].date,
    ).millisecondsSinceEpoch;
    return left + (time - first) / (last - first) * (_nowX - left - 12);
  }

  void _moveTo(Offset local) {
    if (local.dx > _nowX + 6) {
      final t = ((local.dx - _nowX) / (width - right - _nowX)).clamp(0.0, 1.0);
      final nowY = _y(widget.current);
      final ys = widget.targets.map((target) {
        final targetY = _y(target.price);
        final controlY = nowY + (targetY - nowY) * .15;
        return (1 - t) * (1 - t) * nowY +
            2 * (1 - t) * t * controlY +
            t * t * targetY;
      }).toList();
      if (ys.reduce(math.max) - ys.reduce(math.min) < 24) {
        setActiveId(null);
        return;
      }
      var nearest = 0;
      for (var i = 1; i < ys.length; i++) {
        if ((ys[i] - local.dy).abs() < (ys[nearest] - local.dy).abs()) {
          nearest = i;
        }
      }
      setActiveId('t:${widget.targets[nearest].key}');
      return;
    }
    if (widget.history.isEmpty || local.dx > _nowX - 6) {
      setActiveId(null);
      return;
    }
    var index = 0;
    for (var i = 1; i < widget.history.length; i++) {
      if ((_historyX(i) - local.dx).abs() <
          (_historyX(index) - local.dx).abs()) {
        index = i;
      }
    }
    setActiveId('h:${widget.history[index].date}');
  }

  @override
  Widget build(BuildContext context) => _PriceTargetScope(
    state: this,
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? math.min(520.0, constraints.maxWidth)
              : 520.0;
          return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child:
                  widget.child ??
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [BeuiPriceTargetHeader(), BeuiPriceTargetPlot()],
                  ),
            ),
          );
        },
      ),
    ),
  );

  Rect? get _historyPathBounds {
    if (widget.history.isEmpty) return null;
    final bounds = _historyPath(this).getBounds();
    const halfStroke = .75;
    return bounds.inflate(halfStroke);
  }
}

class _PriceTargetScope extends InheritedWidget {
  const _PriceTargetScope({required this.state, required super.child});
  final _BeuiPriceTargetFanState state;
  static _BeuiPriceTargetFanState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_PriceTargetScope>();
    assert(
      scope != null,
      'Price target fan parts must be inside BeuiPriceTargetFan.',
    );
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_PriceTargetScope oldWidget) => true;
}

/// Active projection price, signed change, and target caption.
class BeuiPriceTargetHeader extends StatelessWidget {
  /// Creates the fan header.
  const BeuiPriceTargetHeader({super.key, this.child});

  /// Replaces the default headline, like source `PriceTargetFanHeader` children.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) return child!;
    final state = _PriceTargetScope.of(context);
    final colors = BeuiColors.resolve(context);
    final active = state._resolvedActive;
    final target = active?.type == 'target'
        ? state.widget.targets.firstWhere(
            (t) => t.key == active!.key,
            orElse: () => state.widget.targets[1],
          )
        : state.widget.targets[1];
    final change = (target.price / state.widget.current - 1) * 100;
    const tickerDuration = Duration(milliseconds: 500);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          BeuiNumberTicker(
            value: target.price * 100,
            duration: tickerDuration,
            stagger: Duration.zero,
            prefix: r'$',
            format: (value) => (value / 100).toStringAsFixed(2),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: const BeuiTextTheme().monoFamily,
              fontFamilyFallback: const BeuiTextTheme().monoFamilyFallback,
              letterSpacing: -0.4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          BeuiNumberTicker(
            value: change.abs() * 10,
            duration: tickerDuration,
            stagger: Duration.zero,
            prefix: change >= 0 ? '+' : '−',
            suffix: '%',
            format: (value) => (value / 10).toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: const BeuiTextTheme().monoFamily,
              fontFamilyFallback: const BeuiTextTheme().monoFamilyFallback,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: active?.type == 'target'
                  ? _targetInkColor(state, target, colors)
                  : _sourceTokenInk(
                      change >= 0 ? 'success' : 'warning',
                      colors,
                    ),
            ),
          ),
          Text(
            '${target.key} target',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// Fixed 520×236 plot host.
class BeuiPriceTargetPlot extends StatelessWidget {
  /// Creates a plot host.
  const BeuiPriceTargetPlot({super.key, this.child});

  /// Optional custom plot composition.
  final Widget? child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = constraints.maxWidth.isFinite
          ? math.min(1.0, constraints.maxWidth / 520)
          : 1.0;
      final width = 520 * scale;
      final height = 236 * scale;
      return Center(
        child: SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            alignment: Alignment.topLeft,
            fit: BoxFit.fill,
            child: SizedBox(
              width: 520,
              height: 236,
              child:
                  child ??
                  const Stack(
                    clipBehavior: Clip.none,
                    children: [
                      BeuiPriceTargetSvg(),
                      Positioned.fill(
                        child: IgnorePointer(child: BeuiPriceTargetTooltip()),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      );
    },
  );
}

/// Layered price-target plot surface.
class BeuiPriceTargetSvg extends StatelessWidget {
  /// Creates the SVG-like layered plot surface.
  const BeuiPriceTargetSvg({super.key, this.children});

  /// Plot layers; defaults to axes, history, now, cursor, history-point hit
  /// targets, and target buttons.
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final state = _PriceTargetScope.of(context);
    return Focus(
      canRequestFocus: false,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label:
            '${state.widget.label}: mean ${_formatFanPrice(state.widget.targets[1].price)}, now ${_formatFanPrice(state.widget.current)}',
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          onHover: (event) {
            if (event.kind != PointerDeviceKind.touch) {
              state._moveTo(event.localPosition);
            }
          },
          onExit: (event) {
            if (event.kind != PointerDeviceKind.touch) state.setActiveId(null);
          },
          child: GestureDetector(
            onHorizontalDragUpdate: (event) =>
                state._moveTo(event.localPosition),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (event) => state._moveTo(event.localPosition),
                    onHorizontalDragUpdate: (event) =>
                        state._moveTo(event.localPosition),
                  ),
                ),
                ...(children ??
                    const [
                      IgnorePointer(child: BeuiPriceTargetAxes()),
                      BeuiPriceTargetFanHistory(),
                      IgnorePointer(child: BeuiPriceTargetNow()),
                      IgnorePointer(child: BeuiPriceTargetCursor()),
                      BeuiPriceTargetTargets(),
                    ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Axis and gridline layer.
class BeuiPriceTargetAxes extends StatelessWidget {
  /// Creates axes.
  const BeuiPriceTargetAxes({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PriceAxesPainter(
      _PriceTargetScope.of(context),
      BeuiColors.resolve(context),
    ),
    size: const Size(520, 236),
  );
}

/// Historical line layer.
class BeuiPriceTargetHistory extends StatelessWidget {
  /// Creates the historical price layer.
  const BeuiPriceTargetHistory({super.key});
  @override
  Widget build(BuildContext context) => BeuiChartTween(
    from: 0,
    value: 1,
    duration: const Duration(milliseconds: 900),
    isMovement: true,
    builder: (context, reveal) => CustomPaint(
      painter: _PriceHistoryPainter(
        _PriceTargetScope.of(context),
        BeuiColors.resolve(context),
        reveal,
      ),
      size: const Size(520, 236),
    ),
  );
}

/// Source-aligned history path and its keyboard slider as one chart layer.
class BeuiPriceTargetFanHistory extends StatelessWidget {
  /// Creates the history line and accessible history slider composition.
  const BeuiPriceTargetFanHistory({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: const [
      IgnorePointer(child: BeuiPriceTargetHistory()),
      BeuiPriceTargetHistoryPoints(),
    ],
  );
}

/// Forecast fan and keyboardable target choices.
class BeuiPriceTargetTargets extends StatelessWidget {
  /// Creates target projections.
  const BeuiPriceTargetTargets({super.key});
  @override
  Widget build(BuildContext context) {
    final state = _PriceTargetScope.of(context);
    final colors = BeuiColors.resolve(context);
    return BeuiChartTween(
      from: 0,
      value: 1,
      duration: const Duration(milliseconds: 800),
      delay: const Duration(milliseconds: 850),
      isMovement: true,
      builder: (context, reveal) => ClipRect(
        key: const ValueKey('price-target-fan-reveal'),
        clipper: _FanRevealClip(state._nowX, reveal),
        child: Stack(
          children: [
            IgnorePointer(
              child: Stack(
                children: [
                  for (final target in state.widget.targets)
                    BeuiChartTween(
                      key: ValueKey(target.key),
                      value: state._resolvedActive?.key == target.key
                          ? 4.5
                          : 3.2,
                      duration: const Duration(milliseconds: 300),
                      motion: beuiSpringPanel,
                      isMovement: true,
                      builder: (context, radius) => BeuiChartTween(
                        key: ValueKey(state._resolvedActive?.key == target.key),
                        from: 0,
                        value: 1,
                        duration: const Duration(milliseconds: 350),
                        isMovement: true,
                        builder: (context, solid) => AnimatedOpacity(
                          opacity:
                              state._resolvedActive?.type == 'target' &&
                                  state._resolvedActive?.key != target.key
                              ? .3
                              : 1,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: beuiEaseOut,
                          child: CustomPaint(
                            painter: _PriceTargetsPainter(
                              state,
                              colors,
                              target: target,
                              radius: radius,
                              solid: solid,
                            ),
                            size: const Size(520, 236),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final target in state.widget.targets)
              Positioned(
                left:
                    (_BeuiPriceTargetFanState.width -
                            _BeuiPriceTargetFanState.right -
                            8)
                        .clamp(0.0, 480.0),
                top: (state._y(target.price) - 11).clamp(0.0, 214.0),
                width: 72,
                height: 22,
                child: BeuiChartTooltip(
                  enabled: false,
                  open: state._resolvedActive?.key == target.key,
                  onOpenChange: (open) {
                    if (!open) state.setActiveId(null);
                  },
                  side: BeuiChartTooltipSide.left,
                  content: _fanTargetCard(context, state, target),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => state.setActiveId('t:${target.key}'),
                    onExit: (_) {
                      if (state.activeId == 't:${target.key}') {
                        state.setActiveId(null);
                      }
                    },
                    child: Semantics(
                      button: true,
                      selected: state._resolvedActive?.key == target.key,
                      label:
                          '${target.key} target ${_formatFanPrice(target.price)}, ${target.analysts} analysts',
                      child: Focus(
                        canRequestFocus: false,
                        onKeyEvent: (_, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.escape) {
                            state.setActiveId(null);
                          } else if (event.logicalKey ==
                                  LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.space) {
                            state.setActiveId(
                              state.activeId == 't:${target.key}'
                                  ? null
                                  : 't:${target.key}',
                            );
                          } else {
                            return KeyEventResult.ignored;
                          }
                          return KeyEventResult.handled;
                        },
                        onFocusChange: (focused) {
                          if (focused) {
                            state.setActiveId('t:${target.key}');
                          } else {
                            state.clearBlurredInspection();
                          }
                        },
                        child: Listener(
                          onPointerDown: (event) {
                            state._targetPointerKind = event.kind;
                            if (event.kind == PointerDeviceKind.touch) {
                              state.setActiveId(
                                state.activeId == 't:${target.key}'
                                    ? null
                                    : 't:${target.key}',
                              );
                            } else {
                              state.focusFor(target.key).requestFocus();
                            }
                          },
                          child: TextButton(
                            key: ValueKey('price-target-target-${target.key}'),
                            focusNode: state.focusFor(target.key),
                            onPressed: () {
                              if (state._targetPointerKind !=
                                  PointerDeviceKind.touch) {
                                state.setActiveId('t:${target.key}');
                              }
                            },
                            style: TextButton.styleFrom(
                              overlayColor: Colors.transparent,
                              padding: const EdgeInsets.only(left: 18),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerLeft,
                            ),
                            child: AnimatedOpacity(
                              opacity:
                                  state._resolvedActive?.type == 'target' &&
                                      state._resolvedActive?.key != target.key
                                  ? .3
                                  : 1,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 250),
                              curve: beuiEaseOut,
                              child: Text(
                                _formatTargetPrice(target.price),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: const BeuiTextTheme().monoFamily,
                                  fontFamilyFallback:
                                      const BeuiTextTheme().monoFamilyFallback,
                                  fontWeight: FontWeight.w600,
                                  color: _targetInkColor(state, target, colors),
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
          ],
        ),
      ),
    );
  }
}

/// Hoverable and keyboard-focusable history point hit targets.
class BeuiPriceTargetHistoryPoints extends StatelessWidget {
  /// Creates history point hit targets.
  const BeuiPriceTargetHistoryPoints({super.key});

  @override
  Widget build(BuildContext context) {
    final state = _PriceTargetScope.of(context);
    final colors = BeuiColors.resolve(context);
    final current = state.widget.history.indexWhere(
      (point) => point.date == state._resolvedActive?.date,
    );
    final index = current < 0 ? state.widget.history.length - 1 : current;
    if (index < 0) return const SizedBox.shrink();
    void select(int next) => state.setActiveId(
      'h:${state.widget.history[next.clamp(0, state.widget.history.length - 1)].date}',
    );
    return Focus(
      key: const ValueKey('price-target-history-slider'),
      focusNode: state._historyFocus,
      onFocusChange: (focused) {
        state._setHistoryFocus(focused);
        if (focused) {
          state._setHistoryFocusVisible(
            state._historyPointerKind == null &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional,
          );
          select(state.widget.history.length - 1);
        } else {
          state._setHistoryFocusVisible(false);
          state._historyPointerKind = null;
          state.clearBlurredInspection();
        }
      },
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        switch (event.logicalKey) {
          case LogicalKeyboardKey.home:
            state._historyPointerKind = null;
            state._setHistoryFocusVisible(true);
            select(0);
          case LogicalKeyboardKey.end:
            state._historyPointerKind = null;
            state._setHistoryFocusVisible(true);
            select(state.widget.history.length - 1);
          case LogicalKeyboardKey.arrowRight:
            state._historyPointerKind = null;
            state._setHistoryFocusVisible(true);
            select(index + 1);
          case LogicalKeyboardKey.arrowLeft:
            state._historyPointerKind = null;
            state._setHistoryFocusVisible(true);
            select(index - 1);
          case LogicalKeyboardKey.escape:
            state._historyPointerKind = null;
            state._setHistoryFocusVisible(true);
            state.setActiveId(null);
          default:
            return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Semantics(
        slider: true,
        label: 'Price history',
        value:
            '${state.widget.history[index].date}: \$${state.widget.history[index].price.toStringAsFixed(2)}',
        increasedValue:
            '${(index + 1).clamp(0, state.widget.history.length - 1)}',
        decreasedValue:
            '${(index - 1).clamp(0, state.widget.history.length - 1)}',
        onIncrease: () => select(index + 1),
        onDecrease: () => select(index - 1),
        child: ExcludeFocus(
          child: ExcludeSemantics(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (state._historyFocused && state._historyFocusVisible)
                  Positioned.fromRect(
                    key: const ValueKey('price-target-history-focus-outline'),
                    rect: state._historyPathBounds ?? Rect.zero,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.focusRing, width: 2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                for (
                  var index = 0;
                  index < state.widget.history.length;
                  index++
                )
                  _PriceTargetHistoryHitTarget(
                    state: state,
                    index: index,
                    colors: colors,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceTargetHistoryHitTarget extends StatelessWidget {
  const _PriceTargetHistoryHitTarget({
    required this.state,
    required this.index,
    required this.colors,
  });

  final _BeuiPriceTargetFanState state;
  final int index;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final point = state.widget.history[index];
    final selected = state._resolvedActive?.date == point.date;
    final x = state._historyX(index);
    final y = state._y(point.price);
    return Positioned(
      left: x - 12,
      top: y - 12,
      width: 24,
      height: 24,
      child: BeuiChartTooltip(
        enabled: false,
        open: selected,
        onOpenChange: (open) {
          if (!open && selected) state.setActiveId(null);
        },
        content: BeuiChartTooltipCard(
          title: _scrubDate(point.date),
          titleWidget: _mutedTooltipTitle(context, _scrubDate(point.date)),
          details: [_priceMetric(context, point.price)],
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => state._setHistoryHover(point.date, true),
          onExit: (_) => state._setHistoryHover(point.date, false),
          child: Listener(
            onPointerDown: (event) => state._setHistoryPointerKind(event.kind),
            child: Semantics(
              button: true,
              selected: selected,
              label: '${point.date}, ${point.price.toStringAsFixed(2)}',
              child: GestureDetector(
                key: ValueKey('price-target-history-${point.date}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  state.setActiveId('h:${point.date}');
                  state._historyFocus.requestFocus();
                },
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? colors.primary : Colors.transparent,
                      border: Border.all(
                        color: selected ? colors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: const SizedBox(width: 8, height: 8),
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

/// Current-price guide.
class BeuiPriceTargetNow extends StatefulWidget {
  /// Creates the current price marker.
  const BeuiPriceTargetNow({super.key});
  @override
  State<BeuiPriceTargetNow> createState() => _BeuiPriceTargetNowState();
}

class _BeuiPriceTargetNowState extends State<BeuiPriceTargetNow> {
  Timer? _pulseTimer;
  bool? _reduced;
  int _pulse = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced == reduced) return;
    _reduced = reduced;
    _pulseTimer?.cancel();
    _pulse = 0;
    if (!reduced) {
      _pulseTimer = Timer(const Duration(milliseconds: 1600), () {
        setState(() => _pulse++);
        _pulseTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
          setState(() => _pulse++);
        });
      });
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BeuiChartTween(
    from: 0,
    value: 1,
    delay: const Duration(milliseconds: 850),
    duration: const Duration(milliseconds: 300),
    motion: beuiSpringPanel,
    isMovement: true,
    builder: (context, dot) {
      Widget paint(double? pulse) => CustomPaint(
        painter: _PriceNowPainter(
          _PriceTargetScope.of(context),
          BeuiColors.resolve(context),
          dot: dot,
          pulse: pulse,
        ),
        size: const Size(520, 236),
      );
      if (_reduced! || _pulse == 0) return paint(null);
      return BeuiChartTween(
        key: ValueKey(_pulse),
        from: 0,
        value: 1,
        duration: const Duration(milliseconds: 2200),
        isMovement: true,
        builder: (context, pulse) => paint(pulse),
      );
    },
  );
}

/// Active history cursor and highlight.
class BeuiPriceTargetCursor extends StatelessWidget {
  /// Creates the cursor layer.
  const BeuiPriceTargetCursor({super.key});
  @override
  Widget build(BuildContext context) {
    final state = _PriceTargetScope.of(context);
    final point = state._activeHistory;
    if (point == null) return const SizedBox.expand();
    final index = state.widget.history.indexOf(point);
    const glide = SpringMotion(
      SpringDescription(stiffness: 700, damping: 50, mass: .5),
    );
    return BeuiChartTween(
      value: state._historyX(index),
      duration: const Duration(milliseconds: 200),
      motion: glide,
      isMovement: true,
      builder: (context, x) => BeuiChartTween(
        value: state._y(point.price),
        duration: const Duration(milliseconds: 200),
        motion: glide,
        isMovement: true,
        builder: (context, y) => CustomPaint(
          painter: _PriceCursorPainter(
            state,
            index,
            x,
            y,
            BeuiColors.resolve(context),
          ),
          size: const Size(520, 236),
        ),
      ),
    );
  }
}

/// Floating readout anchored to the active history or target coordinate.
class BeuiPriceTargetTooltip extends StatelessWidget {
  /// Creates the active value tooltip.
  const BeuiPriceTargetTooltip({super.key, this.child, this.contentBuilder});

  /// Optional custom content for the active history or target tooltip.
  final Widget? child;

  /// Builds custom content from source title, metrics, accent, and anchor data.
  final Widget Function(BeuiPriceTargetFanTooltipData data)? contentBuilder;
  @override
  Widget build(BuildContext context) {
    final state = _PriceTargetScope.of(context);
    final active = state._resolvedActive;
    final point = state._activeHistory;
    final target = active?.type == 'target'
        ? state.widget.targets.firstWhere((target) => target.key == active!.key)
        : null;
    final x = target != null
        ? 520 - 108.0
        : point != null
        ? state._historyX(state.widget.history.indexOf(point))
        : 0.0;
    final y = target != null
        ? state._y(target.price)
        : point != null
        ? state._y(point.price)
        : 0.0;
    final data = target != null
        ? BeuiPriceTargetFanTooltipData(
            title:
                '${target.key} target${state.widget.dates.horizon == null ? '' : ' · ${state.widget.dates.horizon}'}',
            anchor: Offset(x, y),
            metrics: [
              BeuiPriceTargetFanTooltipMetric(
                label: 'Price',
                value: _formatFanPrice(target.price),
              ),
              BeuiPriceTargetFanTooltipMetric(
                label: 'Analysts',
                value: '${target.analysts}',
              ),
            ],
            accent: BeuiPriceTargetFanTooltipAccent(
              label: 'vs now',
              value: beuiChartSignedPercent(
                (target.price / state.widget.current - 1) * 100,
              ),
              color:
                  target.color ??
                  switch (state.widget.targets.indexOf(target)) {
                    0 => 'var(--success)',
                    2 => 'var(--warning)',
                    _ => 'var(--accent)',
                  },
            ),
          )
        : point != null
        ? BeuiPriceTargetFanTooltipData(
            title: _scrubDate(point.date),
            anchor: Offset(x, y),
            metrics: [
              BeuiPriceTargetFanTooltipMetric(
                label: 'Price',
                value: _formatFanPrice(point.price),
              ),
            ],
          )
        : null;
    return SizedBox(
      width: 520,
      height: 236,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: x,
            top: y,
            child: BeuiChartTooltip(
              open: active != null,
              onOpenChange: (open) {
                if (!open) state.setActiveId(null);
              },
              content:
                  (data == null
                      ? child
                      : contentBuilder?.call(data) ?? child) ??
                  (target != null
                      ? _fanTargetCard(context, state, target)
                      : point != null
                      ? SizedBox(
                          width: 126,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _mutedTooltipTitle(
                                context,
                                _scrubDate(point.date),
                              ),
                              const SizedBox(height: 6),
                              _priceMetric(context, point.price),
                            ],
                          ),
                        )
                      : const SizedBox.shrink()),
              child: const SizedBox(width: 1, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _priceMetric(BuildContext context, double price) =>
    _metricRow(context, 'Price', '\$${price.toStringAsFixed(2)}');

String _scrubDate(String iso) {
  final date = _historyDate(iso);
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';
}

String _formatFanPrice(double price) => '\$${price.toStringAsFixed(2)}';

String _formatTargetPrice(double price) => price == price.roundToDouble()
    ? price.toStringAsFixed(0)
    : price.toString();

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime? _tryHistoryDate(String iso) {
  try {
    final date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
    if (date == null) return null;
    final year = int.parse(date.group(1)!);
    final month = int.parse(date.group(2)!);
    final day = int.parse(date.group(3)!);
    final calendarDate = DateTime.utc(year, month, day);
    if (calendarDate.year != year ||
        calendarDate.month != month ||
        calendarDate.day != day) {
      return null;
    }
    return _historyDate(iso);
  } on FormatException {
    return null;
  }
}

DateTime _historyDate(String iso) =>
    DateTime.parse(iso.length == 10 ? '${iso}T00:00:00Z' : iso).toUtc();

Widget _fanTargetCard(
  BuildContext context,
  _BeuiPriceTargetFanState state,
  BeuiPriceTarget target,
) {
  final horizon = state.widget.dates.horizon;
  final title = '${target.key} target${horizon == null ? '' : ' · $horizon'}';
  return SizedBox(
    width: 126,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _mutedTooltipTitle(context, title),
        const SizedBox(height: 6),
        _priceMetric(context, target.price),
        const SizedBox(height: 4),
        _metricRow(context, 'Analysts', '${target.analysts}'),
        const Padding(
          padding: EdgeInsets.only(top: 6, bottom: 6),
          child: Divider(height: 1),
        ),
        _metricRow(
          context,
          'vs now',
          beuiChartSignedPercent(
            (target.price / state.widget.current - 1) * 100,
          ),
          valueColor: _targetInkColor(
            state,
            target,
            BeuiColors.resolve(context),
          ),
        ),
      ],
    ),
  );
}

Widget _mutedTooltipTitle(BuildContext context, String title) => Text(
  title,
  style: TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: BeuiColors.resolve(context).mutedForeground,
  ),
);

Widget _metricRow(
  BuildContext context,
  String label,
  String value, {
  Color? valueColor,
}) {
  final foreground = BeuiColors.resolve(context).foreground;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        value,
        style: TextStyle(
          color: valueColor ?? foreground,
          fontSize: 12,
          fontFamily: const BeuiTextTheme().monoFamily,
          fontFamilyFallback: const BeuiTextTheme().monoFamilyFallback,
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );
}

Color _targetColor(
  _BeuiPriceTargetFanState state,
  BeuiPriceTarget target,
  BeuiColors colors,
) {
  final index = state.widget.targets.indexWhere(
    (item) => item.key == target.key,
  );
  final fallback = switch (index) {
    0 => colors.success,
    1 => colors.accent,
    2 => colors.warning,
    _ => colors.accent,
  };
  return beuiChartColor(target.color, colors, fallback: fallback);
}

Color _targetInkColor(
  _BeuiPriceTargetFanState state,
  BeuiPriceTarget target,
  BeuiColors colors,
) {
  final explicit = target.color?.trim();
  if (explicit == null || explicit.isEmpty) {
    final index = state.widget.targets.indexWhere(
      (item) => item.key == target.key,
    );
    return _sourceTokenInk(switch (index) {
      0 => 'success',
      1 => 'accent',
      2 => 'warning',
      _ => 'accent',
    }, colors);
  }
  final role = switch (explicit) {
    'var(--success)' => 'success',
    'var(--accent)' => 'accent',
    'var(--warning)' => 'warning',
    'var(--destructive)' || 'var(--danger)' => 'destructive',
    _ => null,
  };
  return role == null
      ? _targetLiteralInkColor(
          explicit,
          _targetColor(state, target, colors),
          colors,
        )
      : _sourceTokenInk(role, colors);
}

Color _targetLiteralInkColor(String css, Color raw, BeuiColors colors) {
  if (css.startsWith('var(') ||
      css.toLowerCase() == 'currentcolor' ||
      raw.a == 0) {
    return raw;
  }
  final hex = RegExp(
    r'^#(?:[\da-f]{3,4}|[\da-f]{6}|[\da-f]{8})$',
    caseSensitive: false,
  );
  final supportedBySharedParser =
      beuiChartColor(css, colors, fallback: const Color(0x01000000)) !=
      const Color(0x01000000);
  final isLiteral = hex.hasMatch(css) || supportedBySharedParser;
  return isLiteral ? _inkSrgbLiteral(raw, colors.brightness) : raw;
}

Color _inkSrgbLiteral(Color color, Brightness brightness) {
  if (brightness == Brightness.dark) return color;
  double linear(double channel) => channel <= .04045
      ? channel / 12.92
      : math.pow((channel + .055) / 1.055, 2.4).toDouble();
  double cubeRoot(double value) => value < 0
      ? -math.pow(-value, 1 / 3).toDouble()
      : math.pow(value, 1 / 3).toDouble();

  final red = linear(color.r);
  final green = linear(color.g);
  final blue = linear(color.b);
  final l = cubeRoot(
    .4122214708 * red + .5363325363 * green + .0514459929 * blue,
  );
  final m = cubeRoot(
    .2119034982 * red + .6806995451 * green + .1073969566 * blue,
  );
  final s = cubeRoot(
    .0883024619 * red + .2817188376 * green + .6299787005 * blue,
  );
  final lightness = .2104542553 * l + .793617785 * m - .0040720468 * s;
  final a = 1.9779984951 * l - 2.428592205 * m + .4505937099 * s;
  final b = .0259040371 * l + .7827717662 * m - .808675766 * s;
  return _oklchColor(
    math.min(lightness, .5),
    math.sqrt(a * a + b * b),
    math.atan2(b, a) * 180 / math.pi,
    alpha: color.a,
  );
}

/// Applies the source chart's relative-OKLCH ink cap to source-owned palette
/// inputs. Geometry deliberately continues to consume `_targetColor` unchanged.
/// Inputs come from pinned `lib/theme-css.ts` and theme literals, not by
/// reversing BeuiColors' already-clipped and quantized sRGB output.
Color _sourceTokenInk(String role, BeuiColors colors) {
  final sourcePalette = BeuiColors.of(
    BeuiColorTheme.defaultMono,
    colors.brightness,
  );
  final sourceValue = switch (role) {
    'success' => sourcePalette.success,
    'warning' => sourcePalette.warning,
    'destructive' => sourcePalette.destructive,
    _ => sourcePalette.accent,
  };
  final currentValue = switch (role) {
    'success' => colors.success,
    'warning' => colors.warning,
    'destructive' => colors.destructive,
    _ => colors.accent,
  };
  if (currentValue != sourceValue) return currentValue;
  if (colors.brightness == Brightness.dark) {
    return switch (role) {
      'success' => colors.success,
      'warning' => colors.warning,
      'destructive' => colors.destructive,
      _ => colors.accent,
    };
  }
  if (role == 'success') return _oklchColor(.5, .18, 155);
  if (role == 'warning') return _oklchColor(.5, .18, 75);
  if (role == 'destructive') return _oklchColor(.5, .22, 25);
  if (role == 'accent' && colors.colorTheme == BeuiColorTheme.defaultMono) {
    // Pinned generic source CSS: --accent is oklch(72% 0.18 195) in light.
    return _oklchColor(.5, .18, 195);
  }
  // Colored Beui themes act like consumer-level CSS overrides; the pinned
  // generic CSS does not establish their effective source --accent values.
  return colors.accent;
}

Color _oklchColor(
  double lightness,
  double chroma,
  double hue, {
  double alpha = 1,
}) {
  final radians = hue * math.pi / 180;
  final a = chroma * math.cos(radians);
  final b = chroma * math.sin(radians);
  final l1 = lightness + .3963377774 * a + .2158037573 * b;
  final m1 = lightness - .1055613458 * a - .0638541728 * b;
  final s1 = lightness - .0894841775 * a - 1.291485548 * b;
  final l = l1 * l1 * l1;
  final m = m1 * m1 * m1;
  final s = s1 * s1 * s1;
  final red = 4.0767416621 * l - 3.3077115913 * m + .2309699292 * s;
  final green = -1.2684380046 * l + 2.6097574011 * m - .3413193965 * s;
  final blue = -.0041960863 * l - .7034186147 * m + 1.707614701 * s;
  int channel(double linear) {
    final clipped = linear.clamp(0.0, 1.0);
    final encoded = clipped <= .0031308
        ? 12.92 * clipped
        : 1.055 * math.pow(clipped, 1 / 2.4) - .055;
    return (encoded * 255).round().clamp(0, 255);
  }

  return Color.fromARGB(
    (alpha * 255).round().clamp(0, 255),
    channel(red),
    channel(green),
    channel(blue),
  );
}

class _PriceAxesPainter extends CustomPainter {
  _PriceAxesPainter(this.state, this.colors) : widget = state.widget;
  final _BeuiPriceTargetFanState state;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    final values = state._domain;
    final span = values[1] - values[0];
    final magnitude = math
        .pow(10, (math.log(span / 3.2) / math.ln10).floor())
        .toDouble();
    final step = [1, 2, 2.5, 5, 10]
        .map((multiple) => multiple * magnitude)
        .firstWhere((step) => span / step <= 4.2, orElse: () => 10 * magnitude);
    for (
      var value = (values[0] / step).ceil() * step;
      value <= values[1];
      value += step
    ) {
      final y = state._y(value);
      for (var x = _BeuiPriceTargetFanState.left; x < 412; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 2, 412), y), grid);
      }
      _drawText(
        canvas,
        value.toStringAsFixed(step >= 1 ? 0 : 1),
        Offset(0, y - 7),
        colors.mutedForeground,
        9,
        width: 28,
        align: TextAlign.right,
      );
    }
    final date = state.widget.dates;
    String axisDate(String iso) {
      final parsed = _historyDate(iso);
      return '${_months[parsed.month - 1]} ${parsed.year}';
    }

    final history = state.widget.history;
    final middle = history.length ~/ 2;
    final labels = [
      if (history.isNotEmpty)
        (
          x: state._historyX(0),
          text: date.start ?? axisDate(history.first.date),
          align: TextAlign.left,
        ),
      if (history.length > 2)
        (
          x: state._historyX(middle),
          text: date.mid ?? axisDate(history[middle].date),
          align: TextAlign.center,
        ),
      (x: state._nowX, text: 'Now', align: TextAlign.center),
      (
        x: _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right,
        text: date.horizon ?? 'Target',
        align: TextAlign.center,
      ),
    ];
    for (final label in labels) {
      _drawText(
        canvas,
        label.text,
        Offset(label.x - (label.align == TextAlign.left ? 0 : 40), 219),
        colors.mutedForeground,
        9,
        width: 80,
        align: label.align,
      );
    }
  }

  @override
  bool shouldRepaint(_PriceAxesPainter oldDelegate) =>
      oldDelegate.widget != widget || oldDelegate.colors != colors;
}

class _PriceHistoryPainter extends CustomPainter {
  _PriceHistoryPainter(this.state, this.colors, this.reveal)
    : widget = state.widget;
  final _BeuiPriceTargetFanState state;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
  final double reveal;
  @override
  void paint(Canvas canvas, Size size) {
    if (state.widget.history.isEmpty) return;
    final path = _historyPath(state);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * reveal),
      Paint()
        ..color = colors.foreground
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PriceHistoryPainter oldDelegate) =>
      oldDelegate.widget != widget ||
      oldDelegate.colors != colors ||
      oldDelegate.reveal != reveal;
}

Path _historyPath(_BeuiPriceTargetFanState state) {
  final path = Path();
  for (var index = 0; index < state.widget.history.length; index++) {
    final point = state.widget.history[index];
    final position = Offset(state._historyX(index), state._y(point.price));
    if (index == 0) {
      path.moveTo(position.dx, position.dy);
    } else {
      path.lineTo(position.dx, position.dy);
    }
  }
  if (state.widget.history.isNotEmpty) {
    path.lineTo(state._nowX, state._y(state.widget.current));
  }
  return path;
}

class _PriceTargetsPainter extends CustomPainter {
  _PriceTargetsPainter(
    this.state,
    this.colors, {
    required this.target,
    required this.radius,
    required this.solid,
  }) : widget = state.widget,
       active = state._resolvedActive?.key == target.key;
  final _BeuiPriceTargetFanState state;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
  final BeuiPriceTarget target;
  final double radius;
  final double solid;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final currentY = state._y(state.widget.current);
    final start = Offset(state._nowX, currentY);
    final endX =
        _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right;
    final end = Offset(endX, state._y(target.price));
    final color = _targetColor(state, target, colors);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + end.dx) / 2,
        start.dy + (end.dy - start.dy) * .15,
        end.dx,
        end.dy,
      );
    final paint = Paint()
      ..color = color.withValues(alpha: active ? 1 : .75)
      ..strokeWidth = active ? 2.2 : 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 6) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 2, metric.length)),
          paint,
        );
      }
      if (active) {
        canvas.drawPath(metric.extractPath(0, metric.length * solid), paint);
      }
    }
    canvas.drawCircle(end, radius, Paint()..color = colors.background);
    canvas.drawCircle(
      end,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_PriceTargetsPainter oldDelegate) =>
      oldDelegate.widget != widget ||
      oldDelegate.colors != colors ||
      oldDelegate.active != active ||
      oldDelegate.radius != radius ||
      oldDelegate.solid != solid ||
      oldDelegate.target != target;
}

class _FanRevealClip extends CustomClipper<Rect> {
  const _FanRevealClip(this.start, this.progress);
  final double start;
  final double progress;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(start, 0, (size.width - start) * progress, size.height);
  @override
  bool shouldReclip(_FanRevealClip old) =>
      start != old.start || progress != old.progress;
}

Paint _guidePaint(BeuiColors colors, double top, double bottom) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      colors.borderStrong.withValues(alpha: 0),
      colors.borderStrong,
      colors.borderStrong,
    ],
    stops: const [0, .45, 1],
  ).createShader(Rect.fromLTRB(0, top, 520, bottom))
  ..strokeWidth = 1
  ..style = PaintingStyle.stroke;

class _PriceNowPainter extends CustomPainter {
  _PriceNowPainter(
    this.state,
    this.colors, {
    required this.dot,
    required this.pulse,
  }) : widget = state.widget;
  final _BeuiPriceTargetFanState state;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
  final double dot;
  final double? pulse;
  @override
  void paint(Canvas canvas, Size size) {
    final y = state._y(state.widget.current);
    final x = state._nowX;
    final top = _BeuiPriceTargetFanState.top;
    final bottom =
        _BeuiPriceTargetFanState.height - _BeuiPriceTargetFanState.bottom;
    final line = _guidePaint(colors, top, bottom);
    for (var yy = top; yy < bottom; yy += 6) {
      canvas.drawLine(Offset(x, yy), Offset(x, math.min(yy + 3, bottom)), line);
    }
    canvas.drawCircle(
      Offset(x, y),
      3.2 * dot.clamp(0, double.infinity),
      Paint()..color = colors.foreground.withValues(alpha: dot.clamp(0, 1)),
    );
    if (pulse != null) {
      canvas.drawCircle(
        Offset(x, y),
        3.2 * (1 + 1.8 * pulse!),
        Paint()
          ..color = colors.foreground.withValues(
            alpha: .45 * (1 - pulse!).clamp(0, 1),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_PriceNowPainter oldDelegate) =>
      oldDelegate.widget != widget ||
      oldDelegate.colors != colors ||
      oldDelegate.dot != dot ||
      oldDelegate.pulse != pulse;
}

class _PriceCursorPainter extends CustomPainter {
  _PriceCursorPainter(
    this.state,
    this.index,
    this.cursorX,
    this.cursorY,
    this.colors,
  ) : widget = state.widget;
  final _BeuiPriceTargetFanState state;
  final int index;
  final double cursorX;
  final double cursorY;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
  @override
  void paint(Canvas canvas, Size size) {
    if (index < 0 || index >= state.widget.history.length) return;
    final x = cursorX;
    final y = cursorY;
    canvas.drawLine(
      Offset(x, _BeuiPriceTargetFanState.top),
      Offset(
        x,
        _BeuiPriceTargetFanState.height - _BeuiPriceTargetFanState.bottom,
      ),
      _guidePaint(
        colors,
        _BeuiPriceTargetFanState.top,
        _BeuiPriceTargetFanState.height - _BeuiPriceTargetFanState.bottom,
      ),
    );
    canvas.drawCircle(Offset(x, y), 3.2, Paint()..color = colors.foreground);
    canvas.drawCircle(
      Offset(x, y),
      3.2,
      Paint()
        ..color = colors.background
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_PriceCursorPainter oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.cursorX != cursorX ||
      oldDelegate.cursorY != cursorY ||
      oldDelegate.widget != widget ||
      oldDelegate.colors != colors;
}

void _drawText(
  Canvas canvas,
  String text,
  Offset offset,
  Color color,
  double fontSize, {
  double width = 90,
  TextAlign align = TextAlign.left,
}) {
  if (text.isEmpty) return;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: const BeuiTextTheme().monoFamily,
        fontFamilyFallback: const BeuiTextTheme().monoFamilyFallback,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(minWidth: width, maxWidth: width);
  painter.paint(canvas, offset);
}

/// Source-aligned name for [BeuiPriceTargetHeader].
typedef BeuiPriceTargetFanHeader = BeuiPriceTargetHeader;

/// Source-aligned name for [BeuiPriceTargetPlot].
typedef BeuiPriceTargetFanPlot = BeuiPriceTargetPlot;

/// Source-aligned name for [BeuiPriceTargetSvg].
typedef BeuiPriceTargetFanSvg = BeuiPriceTargetSvg;

/// Source-aligned name for [BeuiPriceTargetAxes].
typedef BeuiPriceTargetFanAxes = BeuiPriceTargetAxes;

/// Source-aligned name for [BeuiPriceTargetTargets].
typedef BeuiPriceTargetFanTargets = BeuiPriceTargetTargets;

/// Source-aligned name for [BeuiPriceTargetNow].
typedef BeuiPriceTargetFanNow = BeuiPriceTargetNow;

/// Source-aligned name for [BeuiPriceTargetCursor].
typedef BeuiPriceTargetFanCursor = BeuiPriceTargetCursor;

/// Source-aligned name for [BeuiPriceTargetTooltip].
typedef BeuiPriceTargetFanTooltip = BeuiPriceTargetTooltip;
