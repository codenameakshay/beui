/// Monthly percentage returns with compounded year and range summaries.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/_focus_ring.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart';

/// Row and month coordinate. Month 12 denotes the annual total.
@immutable
class BeuiReturnsCalendarCell {
  /// Creates a cell coordinate.
  const BeuiReturnsCalendarCell({required this.year, required this.month});

  /// Zero-based year row.
  final int year;

  /// Month index, 0–11, or 12 for the compounded year.
  final int month;

  @override
  bool operator ==(Object other) =>
      other is BeuiReturnsCalendarCell &&
      year == other.year &&
      month == other.month;
  @override
  int get hashCode => Object.hash(year, month);
}

/// A selected row-major span of monthly or annual cells.
@immutable
class BeuiReturnsCalendarSelection {
  /// Creates an anchored or locked span.
  const BeuiReturnsCalendarSelection({required this.start, this.end});

  /// First selected cell.
  final BeuiReturnsCalendarCell start;

  /// Optional locked end cell.
  final BeuiReturnsCalendarCell? end;

  @override
  bool operator ==(Object other) =>
      other is BeuiReturnsCalendarSelection &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Calendar of monthly investment returns, with compounded year totals.
class BeuiReturnsCalendar extends StatefulWidget {
  /// Creates a returns calendar.
  const BeuiReturnsCalendar({
    super.key,
    this.years = const [],
    this.returns = const [],
    this.selection,
    this.defaultSelection,
    this.onSelectionChange,
    this.child,
  });

  /// Row labels, one per row of [returns].
  final List<int> years;

  /// `returns[year][month]` percentages, twelve months per row.
  final List<List<double>> returns;

  /// Controlled selection.
  final BeuiReturnsCalendarSelection? selection;

  /// Initial uncontrolled selection.
  final BeuiReturnsCalendarSelection? defaultSelection;

  /// Reports user selection changes.
  final ValueChanged<BeuiReturnsCalendarSelection?>? onSelectionChange;

  /// Custom composition. Defaults to the grid.
  final Widget? child;

  @override
  State<BeuiReturnsCalendar> createState() => _BeuiReturnsCalendarState();
}

class _BeuiReturnsCalendarState extends State<BeuiReturnsCalendar>
    with BeuiChartActiveState<BeuiReturnsCalendar>, BeuiChartInspectorKeys {
  BeuiReturnsCalendarCell? _rangeEnd;
  BeuiReturnsCalendarCell? _hover;
  BeuiReturnsCalendarCell? _dismissed;
  BeuiReturnsCalendarCell? get _hot => _hover ?? _rangeEnd ?? _selection?.start;
  BeuiReturnsCalendarCell? get _tip => _rangeEnd ?? _hover ?? _selection?.start;
  void _dismiss(BeuiReturnsCalendarCell cell) =>
      setState(() => _dismissed = cell);
  void _setHover(BeuiReturnsCalendarCell? cell) => setState(() {
    if (_hover != cell) _dismissed = null;
    _hover = cell;
  });
  BeuiReturnsCalendarSelection? get _preview {
    final selection = _selection;
    if (selection == null) return null;
    final hover = _hover;
    return BeuiReturnsCalendarSelection(
      start: selection.start,
      end:
          selection.end ??
          (hover != null && (hover.month == 12) == (selection.start.month == 12)
              ? hover
              : null),
    );
  }

  @override
  String? get widgetActiveId => _id(widget.selection?.start);
  @override
  String? get widgetDefaultActiveId => _id(widget.defaultSelection?.start);
  @override
  ValueChanged<String?>? get widgetOnActiveChange => null;
  @override
  Iterable<String> get knownIds => inspectableIds;
  @override
  String? get activeId =>
      widget.selection == null ? super.activeId : _id(widget.selection!.start);
  @override
  List<String> get inspectableIds => [
    for (var y = 0; y < widget.years.length; y++)
      for (var m = 0; m <= 12; m++) _id(_cell(y, m))!,
  ];

  @override
  void initState() {
    super.initState();
    initActive();
    _rangeEnd = widget.defaultSelection?.end;
  }

  String? _id(BeuiReturnsCalendarCell? cell) =>
      cell == null ? null : '${cell.year}:${cell.month}';
  BeuiReturnsCalendarCell? _fromId(String? id) {
    if (id == null) return null;
    final p = id.split(':');
    if (p.length != 2) return null;
    return _cell(int.tryParse(p[0]) ?? -1, int.tryParse(p[1]) ?? -1);
  }

  BeuiReturnsCalendarCell _cell(int y, int m) =>
      BeuiReturnsCalendarCell(year: y, month: m);
  double _monthValue(int y, int m) =>
      widget.returns.length > y && widget.returns[y].length > m
      ? widget.returns[y][m]
      : 0;
  double _compound(Iterable<double> values) =>
      (values.fold<double>(1, (acc, value) => acc * (1 + value / 100)) - 1) *
      100;
  double _value(BeuiReturnsCalendarCell cell) => cell.month == 12
      ? _compound(List.generate(12, (m) => _monthValue(cell.year, m)))
      : _monthValue(cell.year, cell.month);
  double? _spanValue(BeuiReturnsCalendarCell cell) {
    final selected = _preview;
    final end = selected?.end;
    if (selected == null ||
        end == null ||
        (selected.start.month == 12) != (end.month == 12)) {
      return null;
    }
    final years = selected.start.month == 12;
    final first = years
        ? (selected.start.year < end.year ? selected.start.year : end.year)
        : (selected.start.year * 12 + selected.start.month <
                  end.year * 12 + end.month
              ? selected.start.year * 12 + selected.start.month
              : end.year * 12 + end.month);
    final last = years
        ? (selected.start.year > end.year ? selected.start.year : end.year)
        : (selected.start.year * 12 + selected.start.month >
                  end.year * 12 + end.month
              ? selected.start.year * 12 + selected.start.month
              : end.year * 12 + end.month);
    if (cell != _tip) return null;
    return _compound(
      years
          ? [
              for (var y = first; y <= last; y++)
                for (var m = 0; m < 12; m++) _monthValue(y, m),
            ]
          : [for (var i = first; i <= last; i++) _monthValue(i ~/ 12, i % 12)],
    );
  }

  String? _spanNote(BeuiReturnsCalendarCell cell) {
    final selected = _preview;
    final end = selected?.end;
    if (selected == null || end == null || _spanValue(cell) == null) {
      return null;
    }
    if (selected.start.month == 12) {
      return '${(selected.start.year - end.year).abs() + 1} years';
    }
    final months =
        ((selected.start.year * 12 + selected.start.month) -
                (end.year * 12 + end.month))
            .abs() +
        1;
    return months > 1 ? '$months months' : null;
  }

  String _tipLabel(BeuiReturnsCalendarCell cell) {
    const names = [
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
    String label(BeuiReturnsCalendarCell c) => c.month == 12
        ? '${widget.years[c.year]}'
        : '${names[c.month]} ${widget.years[c.year]}';
    final selected = _preview;
    final end = selected?.end;
    if (selected == null || end == null || end == selected.start) {
      return label(cell);
    }
    final firstIndex = selected.start.year * 13 + selected.start.month;
    final endIndex = end.year * 13 + end.month;
    return '${label(firstIndex <= endIndex ? selected.start : end)} – ${label(firstIndex <= endIndex ? end : selected.start)}';
  }

  BeuiReturnsCalendarSelection? get _selection {
    if (widget.selection != null) return widget.selection;
    final start = _fromId(super.activeId);
    return start == null
        ? null
        : BeuiReturnsCalendarSelection(start: start, end: _rangeEnd);
  }

  @override
  void setActiveId(String? id) {
    if (id == null) _rangeEnd = null;
    if (widget.selection != null) {
      widget.onSelectionChange?.call(
        id == null ? null : BeuiReturnsCalendarSelection(start: _fromId(id)!),
      );
      return;
    }
    super.setActiveId(id);
  }

  void _select(BeuiReturnsCalendarCell cell) {
    _dismissed = null;
    final selected = _selection;
    if (selected?.end != null) {
      _rangeEnd = null;
      setActiveId(null);
    } else if (selected == null) {
      setActiveId(_id(cell));
    } else if (selected.start == cell) {
      setActiveId(null);
    } else if ((selected.start.month == 12) != (cell.month == 12)) {
      _rangeEnd = null;
      setActiveId(_id(cell));
    } else {
      final next = BeuiReturnsCalendarSelection(
        start: selected.start,
        end: cell,
      );
      if (widget.selection == null) {
        _rangeEnd = cell;
        setState(() {});
      }
      widget.onSelectionChange?.call(next);
    }
  }

  @override
  Widget build(BuildContext context) => _ReturnsCalendarScope(
    state: this,
    child: SizedBox(
      width: 480,
      child: Semantics(
        container: true,
        label: 'Returns calendar',
        child: widget.child ?? const BeuiReturnsCalendarGrid(),
      ),
    ),
  );
}

class _ReturnsCalendarScope extends InheritedWidget {
  const _ReturnsCalendarScope({required this.state, required super.child});
  final _BeuiReturnsCalendarState state;
  static _BeuiReturnsCalendarState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ReturnsCalendarScope>();
    assert(
      scope != null,
      'Returns calendar parts must be inside BeuiReturnsCalendar.',
    );
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_ReturnsCalendarScope oldWidget) => true;
}

/// Month cells and compounded year totals.
class BeuiReturnsCalendarGrid extends StatelessWidget {
  /// Creates the returns grid.
  const BeuiReturnsCalendarGrid({super.key, this.cellWidth});

  /// Optional fixed month width. Otherwise the twelve months fill the row.
  final double? cellWidth;

  @override
  Widget build(BuildContext context) {
    final state = _ReturnsCalendarScope.of(context);
    final colors = BeuiColors.resolve(context);
    final selection = state._preview;
    final start = selection?.start;
    final end = selection?.end ?? start;
    final startIndex = start == null ? -1 : start.year * 13 + start.month;
    final endIndex = end == null ? -1 : end.year * 13 + end.month;
    final low = startIndex < 0
        ? -1
        : (startIndex < endIndex ? startIndex : endIndex);
    final high = startIndex < 0
        ? -1
        : (startIndex > endIndex ? startIndex : endIndex);
    const months = [
      'J',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D',
      'Year',
    ];
    const monthNames = [
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
      'Year',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final monthWidth =
            cellWidth ??
            (constraints.hasBoundedWidth
                ? ((constraints.maxWidth - 136) / 12).clamp(
                    1.0,
                    double.infinity,
                  )
                : 34.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  const [
                    LogicalKeyboardKey.arrowRight,
                    LogicalKeyboardKey.arrowLeft,
                    LogicalKeyboardKey.arrowUp,
                    LogicalKeyboardKey.arrowDown,
                  ].contains(event.logicalKey)) {
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                state._setHover(null);
                state.setActiveId(null);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 32),
                    for (var m = 0; m < months.length; m++) ...[
                      const SizedBox(width: 4),
                      SizedBox(
                        width: m == 12 ? 52 : monthWidth,
                        child: Center(
                          child: Text(
                            months[m],
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                for (var y = 0; y < state.widget.years.length; y++) ...[
                  if (y > 0) const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          _returnsYearLabel(state.widget.years[y]),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (var m = 0; m <= 12; m++) ...[
                        const SizedBox(width: 4),
                        _ReturnsCell(
                          width: m == 12 ? 52 : monthWidth,
                          height: monthWidth,
                          cellKey: 'beui-returns-cell-$y-$m',
                          semanticLabel:
                              '${state.widget.years[y]} ${monthNames[m]} return ${beuiChartSignedPercent(state._value(state._cell(y, m)))}',
                          label: monthNames[m],
                          delay: Duration(milliseconds: (y + m) * 20),
                          annual: m == 12,
                          hot: state._hot == state._cell(y, m),
                          tooltipOpen:
                              state._tip == state._cell(y, m) &&
                              state._dismissed != state._cell(y, m),
                          sweep:
                              state._hover == state._cell(y, 12) &&
                              selection?.start.month != 12,
                          sweepDelay: Duration(milliseconds: m * 35),
                          onHover: (hover) =>
                              state._setHover(hover ? state._cell(y, m) : null),
                          onDismiss: () {
                            state._dismiss(state._cell(y, m));
                          },
                          value: state._value(state._cell(y, m)),
                          background: colors.background,
                          positive: colors.success,
                          negative: colors.destructive,
                          selected:
                              selection != null &&
                              y * 13 + m >= low &&
                              y * 13 + m <= high,
                          dimmed: selection != null
                              ? !(y * 13 + m >= low && y * 13 + m <= high)
                              : state._hot != null &&
                                    state._hot!.year != y &&
                                    state._hot!.month != m,
                          pressed:
                              selection != null &&
                              (state._cell(y, m) == selection.start ||
                                  state._cell(y, m) == selection.end),
                          onTap: () => state._select(state._cell(y, m)),
                          tooltip: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                state._tipLabel(state._cell(y, m)),
                                style: TextStyle(color: colors.mutedForeground),
                              ),
                              BeuiChartTicker(
                                value:
                                    (state._spanValue(state._cell(y, m)) ??
                                            state._value(state._cell(y, m)))
                                        .abs() *
                                    10 /
                                    10,
                                duration: const Duration(milliseconds: 350),
                                style: TextStyle(
                                  color:
                                      (state._spanValue(state._cell(y, m)) ??
                                              state._value(
                                                state._cell(y, m),
                                              )) >=
                                          0
                                      ? colors.success
                                      : colors.destructive,
                                  fontFamily: 'monospace',
                                ),
                                format: (value) {
                                  final signed =
                                      state._spanValue(state._cell(y, m)) ??
                                      state._value(state._cell(y, m));
                                  return '${signed < 0 ? '−' : '+'}${value.toStringAsFixed(1)}%';
                                },
                              ),
                              if (state._spanNote(state._cell(y, m))
                                  case final note?)
                                Text(note)
                              else if (m == 12)
                                const Text('for the year'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReturnsCell extends StatefulWidget {
  const _ReturnsCell({
    required this.width,
    required this.height,
    required this.cellKey,
    required this.semanticLabel,
    required this.label,
    required this.value,
    required this.background,
    required this.positive,
    required this.negative,
    required this.selected,
    required this.dimmed,
    required this.pressed,
    required this.onTap,
    required this.tooltip,
    required this.delay,
    required this.annual,
    required this.hot,
    required this.tooltipOpen,
    required this.onHover,
    required this.sweep,
    required this.sweepDelay,
    required this.onDismiss,
  });
  final double width;
  final double height;
  final String cellKey;
  final String semanticLabel;
  final String label;
  final double value;
  final Color background;
  final Color positive;
  final Color negative;
  final bool selected;
  final bool dimmed;
  final bool pressed;
  final VoidCallback onTap;
  final Widget tooltip;
  final Duration delay;
  final bool annual;
  final bool hot;
  final bool tooltipOpen;
  final ValueChanged<bool> onHover;
  final bool sweep;
  final Duration sweepDelay;
  final VoidCallback onDismiss;
  @override
  State<_ReturnsCell> createState() => _ReturnsCellState();
}

class _ReturnsCellState extends State<_ReturnsCell> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ReturnsCell(
      :width,
      :height,
      :cellKey,
      :semanticLabel,
      :label,
      :value,
      :background,
      :positive,
      :negative,
      :selected,
      :dimmed,
      :pressed,
      :onTap,
      :tooltip,
      :delay,
      :annual,
      :hot,
      :tooltipOpen,
      :onHover,
      :sweep,
      :sweepDelay,
      :onDismiss,
    ) = widget;
    final tint = value >= 0 ? positive : negative;
    final intensity = (value.abs() / 8).clamp(0.0, 1.0);
    final colors = BeuiColors.resolve(context);
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: EdgeInsets.zero,
        child: BeuiChartTooltip(
          enabled: true,
          open: tooltipOpen,
          onOpenChange: (open) {
            if (!open) onDismiss();
          },
          content: tooltip,
          child: Semantics(
            button: true,
            selected: pressed,
            label: semanticLabel,
            child: InkWell(
              key: ValueKey(cellKey),
              focusNode: _focus,
              onTap: () {
                _focus.requestFocus();
                onTap();
              },
              onHover: onHover,
              onFocusChange: onHover,
              child: BeuiFocusRing(
                focused: hot,
                borderRadius: BorderRadius.circular(4),
                child: BeuiChartTween(
                  value: 1,
                  from: 0,
                  duration: const Duration(milliseconds: 400),
                  delay: delay,
                  snapWhenReduced: true,
                  builder: (context, entrance) => Opacity(
                    opacity: entrance.clamp(0, 1),
                    child: BeuiChartTween(
                      value: hot && !annual ? 1.15 : 1,
                      from: annual ? 1 : .6,
                      duration: const Duration(milliseconds: 300),
                      delay: delay,
                      motion: beuiSpringPress,
                      isMovement: true,
                      builder: (context, scale) => Transform.scale(
                        scale: scale,
                        child: _ReturnsWave(
                          active: sweep && !annual,
                          delay: sweepDelay,
                          child: BeuiChartFade(
                            opacity: dimmed ? .35 : 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: annual
                                    ? hot
                                          ? background
                                          : colors.foreground.withValues(
                                              alpha: .06,
                                            )
                                    : Color.alphaBlend(
                                        tint.withValues(
                                          alpha:
                                              (hot ? .24 : .08) +
                                              intensity * .55,
                                        ),
                                        background,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                                border: selected
                                    ? Border.all(
                                        color: tint.withValues(alpha: .65),
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  _returnsCellLabel(label, value),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: annual
                                        ? tint
                                        : colors.foreground.withValues(
                                            alpha: .85 + intensity * .15,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _ReturnsWave extends StatefulWidget {
  const _ReturnsWave({
    required this.active,
    required this.delay,
    required this.child,
  });
  final bool active;
  final Duration delay;
  final Widget child;
  @override
  State<_ReturnsWave> createState() => _ReturnsWaveState();
}

class _ReturnsWaveState extends State<_ReturnsWave>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.delay + const Duration(milliseconds: 360),
  );
  @override
  void didUpdateWidget(covariant _ReturnsWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.forward(from: 0);
    if (!widget.active) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final ms =
          _controller.value * _controller.duration!.inMilliseconds -
          widget.delay.inMilliseconds;
      final t = (ms / 360).clamp(0.0, 1.0);
      final eased = beuiEaseOut.transform(t);
      final pulse = eased < .5 ? eased * 2 : (1 - eased) * 2;
      return Transform.scale(
        scale: widget.active && !MediaQuery.disableAnimationsOf(context)
            ? 1 + .1 * pulse
            : 1,
        child: widget.child,
      );
    },
  );
}

String _returnsCellLabel(String label, double value) {
  if (label == 'Year') {
    return beuiChartSignedPercent(value, digits: 0);
  }
  if (value.abs() < 4) return '';
  final rounded = (value + 0.5).floor();
  if (rounded < 0) return '−${rounded.abs()}';
  return '$rounded';
}

String _returnsYearLabel(int year) =>
    "'${year.toString().padLeft(4, '0').substring(2)}";

/// Tooltip composition slot. Tooltips are hosted by individual month cells.
class BeuiReturnsCalendarTooltip extends StatelessWidget {
  /// Creates the tooltip slot.
  const BeuiReturnsCalendarTooltip({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
