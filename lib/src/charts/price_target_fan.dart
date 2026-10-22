/// Historical prices with high, mean and low analyst projections.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/number_ticker.dart';
import '../theme/beui_colors.dart';
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
  static const double right = 52;
  static const double top = 16;
  static const double bottom = 28;
  final Set<String> _hoveredHistoryDates = {};

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
      _hoveredHistoryDates.add(date);
      setActiveId(id);
    } else {
      _hoveredHistoryDates.remove(date);
      if (activeId == id) setActiveId(null);
    }
  }

  void _setHistoryFocus(String date, bool focused) {
    final id = 'h:$date';
    if (focused) {
      setActiveId(id);
    } else if (!_hoveredHistoryDates.contains(date) && activeId == id) {
      setActiveId(null);
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
    final pad = math.max((maxValue - minValue) * .08, 8);
    return [math.max(0, minValue - pad), maxValue + pad];
  }

  double _y(double price) {
    final domain = _domain;
    return top +
        (domain[1] - price) / (domain[1] - domain[0]) * (height - top - bottom);
  }

  double get _nowX => left + (width - left - right) * 0.52;
  double _historyX(int index) {
    if (widget.history.length <= 1) return left;
    return left + index / (widget.history.length - 1) * (_nowX - left);
  }

  void _moveTo(Offset local) {
    if (widget.history.isEmpty) return;
    final span = _nowX - left;
    if (span <= 0) return;
    final t = ((local.dx - left) / span).clamp(0.0, 1.0);
    final index = (t * (widget.history.length - 1)).round().clamp(
      0,
      widget.history.length - 1,
    );
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
            children: [
              BeuiPriceTargetHeader(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  BeuiPriceTargetPlot(),
                  Positioned(
                    top: 242,
                    left: 0,
                    right: 0,
                    child: BeuiPriceTargetTooltip(),
                  ),
                ],
              ),
            ],
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
      child: child ?? const BeuiPriceTargetSvg(),
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
      autofocus: true,
      onKeyEvent: (_, event) => state.handleInspectorKey(event)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label:
            '${state.widget.label}, current ${state.widget.current}, mean target ${state.widget.targets[1].price}',
        child: GestureDetector(
          onHorizontalDragUpdate: (event) => state._moveTo(event.localPosition),
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
  Widget build(BuildContext context) => CustomPaint(
    painter: _PriceHistoryPainter(
      _PriceTargetScope.of(context),
      BeuiColors.resolve(context),
    ),
    size: const Size(520, 236),
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
    return Stack(
      children: [
        IgnorePointer(
          child: CustomPaint(
            painter: _PriceTargetsPainter(state, colors),
            size: const Size(520, 236),
          ),
        ),
        for (final target in state.widget.targets)
          Positioned(
            left:
                (_BeuiPriceTargetFanState.width -
                        _BeuiPriceTargetFanState.right -
                        6)
                    .clamp(0.0, 480.0),
            top: (state._y(target.price) - 11).clamp(0.0, 214.0),
            width: 50,
            height: 22,
            child: BeuiChartTooltip(
              side: BeuiChartTooltipSide.left,
              content: BeuiChartTooltipCard(
                title: '${target.key} target',
                titleWidget: _mutedTooltipTitle(
                  context,
                  '${target.key} target',
                ),
                details: [
                  _priceMetric(context, target.price),
                  _metricRow(context, 'Analysts', '${target.analysts}'),
                ],
              ),
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
                  child: TextButton(
                    key: ValueKey('price-target-target-${target.key}'),
                    onPressed: () => state.setActiveId('t:${target.key}'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(
                      target.price.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _targetColor(state, target, colors),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var index = 0; index < state.widget.history.length; index++)
          _PriceTargetHistoryHitTarget(
            state: state,
            index: index,
            colors: colors,
          ),
      ],
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
        content: BeuiChartTooltipCard(
          title: point.date,
          titleWidget: _mutedTooltipTitle(context, point.date),
          details: [_priceMetric(context, point.price)],
        ),
        child: Focus(
          onFocusChange: (focused) {
            state._setHistoryFocus(point.date, focused);
          },
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
                onTap: () => state.setActiveId('h:${point.date}'),
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
class BeuiPriceTargetNow extends StatelessWidget {
  /// Creates the current price marker.
  const BeuiPriceTargetNow({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PriceNowPainter(
      _PriceTargetScope.of(context),
      BeuiColors.resolve(context),
    ),
    size: const Size(520, 236),
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
    return BeuiChartSpring(
      value: state._y(point.price),
      builder: (context, y) => BeuiChartFade(
        opacity: 1,
        child: CustomPaint(
          painter: _PriceCursorPainter(
            state,
            index,
            y,
            BeuiColors.resolve(context),
          ),
          size: const Size(520, 236),
        ),
      ),
    );
  }
}

/// Active-point tooltip content.
class BeuiPriceTargetTooltip extends StatelessWidget {
  /// Creates the active value tooltip.
  const BeuiPriceTargetTooltip({super.key});
  @override
  Widget build(BuildContext context) {
    final state = _PriceTargetScope.of(context);
    final active = state._resolvedActive;
    if (active == null) return const SizedBox.shrink();
    if (active.type == 'target') {
      final target = state.widget.targets.firstWhere(
        (t) => t.key == active.key,
      );
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: BeuiChartTooltipCard(
          title: '${target.key} target',
          titleWidget: _mutedTooltipTitle(context, '${target.key} target'),
          details: [
            _priceMetric(context, target.price),
            _metricRow(context, 'Analysts', '${target.analysts}'),
          ],
        ),
      );
    }
    final point = state.widget.history.firstWhere((p) => p.date == active.date);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: BeuiChartTooltipCard(
        title: point.date,
        titleWidget: _mutedTooltipTitle(context, point.date),
        details: [_priceMetric(context, point.price)],
      ),
    );
  }
}

Widget _priceMetric(BuildContext context, double price) =>
    _metricRow(context, 'Price', null, tickerValue: price);

Widget _mutedTooltipTitle(BuildContext context, String title) => Text(
  title,
  style: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: BeuiColors.resolve(context).mutedForeground,
  ),
);

Widget _metricRow(
  BuildContext context,
  String label,
  String? value, {
  double? tickerValue,
}) {
  final muted = BeuiColors.resolve(context).mutedForeground;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(color: muted)),
      const SizedBox(width: 12),
      if (tickerValue != null)
        BeuiChartTicker(
          value: tickerValue,
          duration: const Duration(milliseconds: 500),
          format: (number) => '\$${number.toStringAsFixed(2)}',
          style: TextStyle(color: muted),
        )
      else
        Text(value ?? '', style: TextStyle(color: muted)),
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
      ..color = colors.border.withValues(alpha: .65)
      ..strokeWidth = 1;
    final values = state._domain;
    for (var i = 0; i <= 4; i++) {
      final y =
          _BeuiPriceTargetFanState.top +
          i *
              (_BeuiPriceTargetFanState.height -
                  _BeuiPriceTargetFanState.top -
                  _BeuiPriceTargetFanState.bottom) /
              4;
      canvas.drawLine(
        Offset(_BeuiPriceTargetFanState.left, y),
        Offset(
          _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right,
          y,
        ),
        grid,
      );
      _drawText(
        canvas,
        '\$${(values[1] - i * (values[1] - values[0]) / 4).toStringAsFixed(0)}',
        Offset(0, y - 7),
        colors.mutedForeground,
        9,
        width: 30,
        align: TextAlign.right,
      );
    }
    final date = state.widget.dates;
    final labels = [
      date.start ??
          (state.widget.history.isEmpty ? '' : state.widget.history.first.date),
      if (date.mid != null) date.mid!,
      'Now',
      date.horizon ?? 'Target',
    ];
    final xs = [
      _BeuiPriceTargetFanState.left,
      if (date.mid != null) (_BeuiPriceTargetFanState.left + state._nowX) / 2,
      state._nowX,
      _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right,
    ];
    for (var i = 0; i < labels.length; i++) {
      _drawText(
        canvas,
        labels[i],
        Offset(xs[i] - 24, 212),
        colors.mutedForeground,
        9,
        width: 55,
        align: TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(_PriceAxesPainter oldDelegate) =>
      oldDelegate.widget != widget || oldDelegate.colors != colors;
}

class _PriceHistoryPainter extends CustomPainter {
  _PriceHistoryPainter(this.state, this.colors) : widget = state.widget;
  final _BeuiPriceTargetFanState state;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
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
    canvas.drawPath(
      path,
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
      oldDelegate.widget != widget || oldDelegate.colors != colors;
}

class _PriceTargetsPainter extends CustomPainter {
  _PriceTargetsPainter(this.state, this.colors) : widget = state.widget;
  final _BeuiPriceTargetFanState state;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
  @override
  void paint(Canvas canvas, Size size) {
    final currentY = state._y(state.widget.current);
    final ordered = state.widget.targets;
    final start = Offset(state._nowX, currentY);
    final endX =
        _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right;
    if (ordered.length >= 3) {
      final high = Offset(endX, state._y(ordered[0].price));
      final low = Offset(endX, state._y(ordered[2].price));
      final band = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + (high.dx - start.dx) * 0.5,
          start.dy,
          start.dx + (high.dx - start.dx) * 0.55,
          high.dy,
          high.dx,
          high.dy,
        )
        ..lineTo(low.dx, low.dy)
        ..cubicTo(
          start.dx + (low.dx - start.dx) * 0.55,
          low.dy,
          start.dx + (low.dx - start.dx) * 0.5,
          start.dy,
          start.dx,
          start.dy,
        )
        ..close();
      canvas.drawPath(
        band,
        Paint()..color = colors.accent.withValues(alpha: .08),
      );
    }
    for (final target in ordered) {
      final end = Offset(endX, state._y(target.price));
      final color = _targetColor(state, target, colors);
      _drawDashedCubic(
        canvas,
        start,
        end,
        Paint()
          ..color = color.withValues(alpha: .85)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(end, 5, Paint()..color = colors.background);
      canvas.drawCircle(
        end,
        5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(_PriceTargetsPainter oldDelegate) =>
      oldDelegate.widget != widget || oldDelegate.colors != colors;
}

class _PriceNowPainter extends CustomPainter {
  _PriceNowPainter(this.state, this.colors) : widget = state.widget;
  final _BeuiPriceTargetFanState state;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
  @override
  void paint(Canvas canvas, Size size) {
    final y = state._y(state.widget.current);
    final x = state._nowX;
    final line = Paint()
      ..color = colors.foreground.withValues(alpha: .35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final top = _BeuiPriceTargetFanState.top;
    final bottom =
        _BeuiPriceTargetFanState.height - _BeuiPriceTargetFanState.bottom;
    for (var yy = top; yy < bottom; yy += 6) {
      canvas.drawLine(Offset(x, yy), Offset(x, math.min(yy + 3, bottom)), line);
    }
    canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = colors.background);
    canvas.drawCircle(Offset(x, y), 3, Paint()..color = colors.foreground);
  }

  @override
  bool shouldRepaint(_PriceNowPainter oldDelegate) =>
      oldDelegate.widget != widget || oldDelegate.colors != colors;
}

class _PriceCursorPainter extends CustomPainter {
  _PriceCursorPainter(this.state, this.index, this.cursorY, this.colors)
    : widget = state.widget;
  final _BeuiPriceTargetFanState state;
  final int index;
  final double cursorY;
  final BeuiColors colors;
  final BeuiPriceTargetFan widget;
  @override
  void paint(Canvas canvas, Size size) {
    if (index < 0 || index >= state.widget.history.length) return;
    final point = state.widget.history[index];
    final x = state._historyX(index);
    final y = cursorY;
    canvas.drawLine(
      Offset(x, _BeuiPriceTargetFanState.top),
      Offset(
        x,
        _BeuiPriceTargetFanState.height - _BeuiPriceTargetFanState.bottom,
      ),
      Paint()
        ..color = colors.foreground.withValues(alpha: .25)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = colors.background);
    canvas.drawCircle(Offset(x, y), 3, Paint()..color = colors.accent);
    _drawText(
      canvas,
      '\$${point.price.toStringAsFixed(2)}',
      Offset(x - 34, y - 21),
      colors.foreground,
      10,
      width: 68,
      align: TextAlign.center,
    );
  }

  @override
  bool shouldRepaint(_PriceCursorPainter oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.cursorY != cursorY ||
      oldDelegate.widget != widget ||
      oldDelegate.colors != colors;
}

void _drawDashedCubic(Canvas canvas, Offset start, Offset end, Paint paint) {
  final path = Path()
    ..moveTo(start.dx, start.dy)
    ..cubicTo(
      start.dx + (end.dx - start.dx) * 0.5,
      start.dy,
      start.dx + (end.dx - start.dx) * 0.55,
      end.dy,
      end.dx,
      end.dy,
    );
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    const dash = 5.0;
    const gap = 3.5;
    while (distance < metric.length) {
      final next = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance = next + gap;
    }
  }
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
  )..layout(maxWidth: width);
  painter.paint(canvas, offset);
}
