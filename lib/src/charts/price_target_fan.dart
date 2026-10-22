/// Historical prices with high, mean and low analyst projections.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  static const double right = 108;
  static const double top = 16;
  static const double bottom = 28;

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
    if (input.targets.length != 3 ||
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
    final pad = math.max((maxValue - minValue) * .16, maxValue * .06);
    return [math.max(0, minValue - pad), maxValue + pad];
  }

  double _y(double price) {
    final domain = _domain;
    return top +
        (domain[1] - price) / (domain[1] - domain[0]) * (height - top - bottom);
  }

  double _historyX(int index) => widget.history.length <= 1
      ? left
      : left +
            index / (widget.history.length - 1) * (width - left - right - 10);
  double get _nowX => widget.history.isEmpty
      ? width * .56
      : _historyX(widget.history.length - 1) + 12;
  void _moveTo(Offset local) {
    if (widget.history.isEmpty) return;
    final index = ((local.dx / width) * widget.history.length).round().clamp(
      0,
      widget.history.length - 1,
    );
    setActiveId('h:${widget.history[index].date}');
  }

  void _stepHistory(int direction) {
    if (widget.history.isEmpty) return;
    final current = widget.history.indexWhere(
      (p) => p.date == _resolvedActive?.date,
    );
    final index =
        (current < 0 ? widget.history.length - 1 : current + direction).clamp(
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
              BeuiPriceTargetPlot(),
              BeuiPriceTargetTooltip(),
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

/// Current price and active projection summary, with history step controls.
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${state.widget.current.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  active?.type == 'history'
                      ? active!.date!
                      : '${target.key} target  ${beuiChartSignedPercent(change)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: active?.type == 'history'
                        ? colors.mutedForeground
                        : change >= 0
                        ? colors.success
                        : colors.destructive,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Previous history point',
            onPressed: () => state._stepHistory(-1),
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Next history point',
            onPressed: () => state._stepHistory(1),
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
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

  /// Plot layers; defaults to axes, history, targets, now, cursor.
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
                  BeuiPriceTargetTargets(),
                ]),
          ],
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
    painter: _PriceAxesPainter(_PriceTargetScope.of(context)),
    size: const Size(520, 236),
  );
}

/// Historical line layer.
class BeuiPriceTargetHistory extends StatelessWidget {
  /// Creates the historical price layer.
  const BeuiPriceTargetHistory({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PriceHistoryPainter(_PriceTargetScope.of(context)),
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
        CustomPaint(
          painter: _PriceTargetsPainter(state, colors),
          size: const Size(520, 236),
        ),
        for (final target in state.widget.targets)
          Positioned(
            right: 0,
            top: (state._y(target.price) - 15).clamp(0.0, 204.0),
            width: 104,
            height: 30,
            child: Semantics(
              button: true,
              selected: state._resolvedActive?.key == target.key,
              label:
                  '${target.key} target ${target.price}, ${target.analysts} analysts',
              child: TextButton(
                onPressed: () => state.setActiveId('t:${target.key}'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  '${target.key}  \$${target.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: _targetColor(state, target, colors),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Current-price guide.
class BeuiPriceTargetNow extends StatelessWidget {
  /// Creates the current price marker.
  const BeuiPriceTargetNow({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PriceNowPainter(_PriceTargetScope.of(context)),
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
          painter: _PriceCursorPainter(state, index, y),
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
          lines: [
            '\$${target.price.toStringAsFixed(2)}',
            '${target.analysts} analysts',
          ],
        ),
      );
    }
    final point = state.widget.history.firstWhere((p) => p.date == active.date);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: BeuiChartTooltipCard(
        title: point.date,
        lines: ['\$${point.price.toStringAsFixed(2)}'],
      ),
    );
  }
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
  _PriceAxesPainter(this.state);
  final _BeuiPriceTargetFanState state;
  @override
  void paint(Canvas canvas, Size size) {
    final colors = BeuiColors.resolve(state.context);
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
      'Now',
      date.horizon ?? 'Target',
    ];
    final xs = [
      _BeuiPriceTargetFanState.left,
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
      oldDelegate.state.widget != state.widget;
}

class _PriceHistoryPainter extends CustomPainter {
  _PriceHistoryPainter(this.state);
  final _BeuiPriceTargetFanState state;
  @override
  void paint(Canvas canvas, Size size) {
    if (state.widget.history.isEmpty) return;
    final colors = BeuiColors.resolve(state.context);
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
        ..color = colors.accent
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < state.widget.history.length; i++) {
      final point = state.widget.history[i];
      canvas.drawCircle(
        Offset(state._historyX(i), state._y(point.price)),
        2.3,
        Paint()..color = colors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_PriceHistoryPainter oldDelegate) =>
      oldDelegate.state.widget != state.widget;
}

class _PriceTargetsPainter extends CustomPainter {
  _PriceTargetsPainter(this.state, this.colors);
  final _BeuiPriceTargetFanState state;
  final BeuiColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final currentY = state._y(state.widget.current);
    final band = Path();
    final ordered = state.widget.targets;
    band.moveTo(state._nowX, state._y(ordered[0].price));
    band.lineTo(
      _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right,
      state._y(ordered[0].price),
    );
    band.lineTo(
      _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right,
      state._y(ordered[2].price),
    );
    band.lineTo(state._nowX, currentY);
    band.close();
    canvas.drawPath(
      band,
      Paint()..color = colors.accent.withValues(alpha: .08),
    );
    for (final target in ordered) {
      final y = state._y(target.price);
      final color = _targetColor(state, target, colors);
      canvas.drawLine(
        Offset(state._nowX, currentY),
        Offset(
          _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right,
          y,
        ),
        Paint()
          ..color = color.withValues(alpha: .65)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_PriceTargetsPainter oldDelegate) =>
      oldDelegate.state.widget != state.widget;
}

class _PriceNowPainter extends CustomPainter {
  _PriceNowPainter(this.state);
  final _BeuiPriceTargetFanState state;
  @override
  void paint(Canvas canvas, Size size) {
    final colors = BeuiColors.resolve(state.context);
    final y = state._y(state.widget.current);
    final line = Paint()
      ..color = colors.foreground.withValues(alpha: .45)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (
      var x = state._nowX;
      x < _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right;
      x += 6
    ) {
      canvas.drawLine(
        Offset(x, y),
        Offset(
          math.min(
            x + 3,
            _BeuiPriceTargetFanState.width - _BeuiPriceTargetFanState.right,
          ),
          y,
        ),
        line,
      );
    }
    canvas.drawCircle(
      Offset(state._nowX, y),
      4,
      Paint()..color = colors.background,
    );
    canvas.drawCircle(
      Offset(state._nowX, y),
      2.5,
      Paint()..color = colors.foreground,
    );
  }

  @override
  bool shouldRepaint(_PriceNowPainter oldDelegate) =>
      oldDelegate.state.widget != state.widget;
}

class _PriceCursorPainter extends CustomPainter {
  _PriceCursorPainter(this.state, this.index, this.cursorY);
  final _BeuiPriceTargetFanState state;
  final int index;
  final double cursorY;
  @override
  void paint(Canvas canvas, Size size) {
    if (index < 0 || index >= state.widget.history.length) return;
    final colors = BeuiColors.resolve(state.context);
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
      oldDelegate.state.widget != state.widget;
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
