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

/// Data and interaction owner for a composable price-target fan.
class BeuiPriceTargetFan extends StatefulWidget {
  /// Creates a price-target fan.
  const BeuiPriceTargetFan({
    super.key,
    required this.current,
    required this.targets,
    this.dates = const BeuiPriceTargetDates(),
    this.history = const [],
    this.label = 'Price target fan',
    this.active,
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

  FocusNode focusFor(String key) =>
      _targetFocus.putIfAbsent(key, FocusNode.new);

  void clearBlurredInspection() {
    if (!_historyFocus.hasFocus &&
        !_targetFocus.values.any((focus) => focus.hasFocus)) {
      setActiveId(null);
    }
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
  String? get activeId =>
      widget.active == null ? super.activeId : _id(widget.active);
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
        input.targets.map((target) => target.price).toSet().length != 3 ||
        input.targets.map((target) => target.key).toSet().length != 3 ||
        input.targets.any((target) => target.key.trim().isEmpty)) {
      throw ArgumentError(
        'BeuiPriceTargetFan requires exactly three unique positive targets.',
      );
    }
    String? previous;
    for (final point in input.history) {
      final parsed = DateTime.tryParse(point.date);
      final isoDate = RegExp(
        r'^\d{4}-\d{2}-\d{2}(?:T.*)?$',
      ).hasMatch(point.date);
      if (!isoDate ||
          parsed == null ||
          !point.price.isFinite ||
          point.price <= 0) {
        throw ArgumentError(
          'BeuiPriceTargetFan history requires positive prices and ISO dates.',
        );
      }
      if (previous != null && point.date.compareTo(previous) <= 0) {
        throw ArgumentError(
          'BeuiPriceTargetFan history dates must be strictly increasing.',
        );
      }
      previous = point.date;
    }
  }

  @override
  void setActiveId(String? id) {
    if (widget.active != null) {
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
      label: widget.label,
      child:
          widget.child ??
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [BeuiPriceTargetHeader(), BeuiPriceTargetPlot()],
          ),
    ),
  );
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
  const BeuiPriceTargetHeader({super.key});

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
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
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: change >= 0 ? colors.success : colors.destructive,
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
  Widget build(BuildContext context) => Center(
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
            '${state.widget.label}, current ${state.widget.current}, mean target ${state.widget.targets[1].price}',
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
                      IgnorePointer(child: BeuiPriceTargetHistory()),
                      IgnorePointer(child: BeuiPriceTargetNow()),
                      IgnorePointer(child: BeuiPriceTargetCursor()),
                      BeuiPriceTargetHistoryPoints(),
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
                        builder: (context, solid) => BeuiChartTween(
                          value:
                              state._resolvedActive?.type == 'target' &&
                                  state._resolvedActive?.key != target.key
                              ? .3
                              : 1,
                          duration: const Duration(milliseconds: 250),
                          snapWhenReduced: true,
                          builder: (context, opacity) => Opacity(
                            opacity: opacity.clamp(0, 1),
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
                          '${target.key} target ${target.price}, ${target.analysts} analysts',
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
                            child: BeuiChartTween(
                              value:
                                  state._resolvedActive?.type == 'target' &&
                                      state._resolvedActive?.key != target.key
                                  ? .3
                                  : 1,
                              duration: const Duration(milliseconds: 250),
                              snapWhenReduced: true,
                              builder: (context, opacity) => Opacity(
                                opacity: opacity.clamp(0, 1),
                                child: Text(
                                  target.price.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: _targetColor(state, target, colors),
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
      onFocusChange: (focused) => focused
          ? state._activeHistory == null
                ? select(state.widget.history.length - 1)
                : null
          : state.clearBlurredInspection(),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        switch (event.logicalKey) {
          case LogicalKeyboardKey.home:
            select(0);
          case LogicalKeyboardKey.end:
            select(state.widget.history.length - 1);
          case LogicalKeyboardKey.arrowRight:
            select(index + 1);
          case LogicalKeyboardKey.arrowLeft:
            select(index - 1);
          case LogicalKeyboardKey.escape:
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
  const BeuiPriceTargetTooltip({super.key});
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
    return Stack(
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
            content: target != null
                ? _fanTargetCard(context, state, target)
                : point != null
                ? SizedBox(
                    width: 126,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _mutedTooltipTitle(context, _scrubDate(point.date)),
                        const SizedBox(height: 6),
                        _priceMetric(context, point.price),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            child: const SizedBox(width: 1, height: 1),
          ),
        ),
      ],
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
          valueColor: _targetColor(state, target, BeuiColors.resolve(context)),
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
          fontFamily: 'monospace',
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
) => beuiChartColor(
  target.color,
  colors,
  fallback: target.key.toLowerCase() == 'high'
      ? colors.success
      : target.key.toLowerCase() == 'low'
      ? colors.warning
      : colors.accent,
);

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
    final path = Path();
    for (var i = 0; i < state.widget.history.length; i++) {
      final p = state.widget.history[i];
      final point = Offset(state._historyX(i), state._y(p.price));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.lineTo(state._nowX, state._y(state.widget.current));
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * reveal),
      Paint()
        ..color = colors.foreground
        ..strokeWidth = 1.6
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
        fontFamily: 'monospace',
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(minWidth: width, maxWidth: width);
  painter.paint(canvas, offset);
}
