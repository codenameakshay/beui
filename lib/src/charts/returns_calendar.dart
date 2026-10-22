/// Monthly percentage returns with compounded year and range summaries.
library;

import 'package:flutter/material.dart';

import '../motion/_focus_ring.dart';
import '../theme/beui_colors.dart';
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
    final selected = _selection;
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
    final index = years ? cell.year : cell.year * 12 + cell.month;
    if (index != last) return null;
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
    final selected = _selection;
    final end = selected?.end;
    if (selected == null || end == null || _spanValue(cell) == null) {
      return null;
    }
    if (selected.start.month == 12) {
      return '${(selected.start.year - end.year).abs() + 1} years compounded';
    }
    final months =
        ((selected.start.year * 12 + selected.start.month) -
                (end.year * 12 + end.month))
            .abs() +
        1;
    return '$months months compounded';
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
    child: Semantics(
      container: true,
      label: 'Returns calendar',
      child: widget.child ?? const BeuiReturnsCalendarGrid(),
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
  const BeuiReturnsCalendarGrid({super.key, this.cellWidth = 34});

  /// Width of each month/year cell.
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    final state = _ReturnsCalendarScope.of(context);
    final colors = BeuiColors.resolve(context);
    final selection = state._selection;
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => state.handleInspectorKey(event)
            ? KeyEventResult.handled
            : KeyEventResult.ignored,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    'Year',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
                for (final month in months)
                  SizedBox(
                    width: cellWidth,
                    child: Center(
                      child: Text(
                        month,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var y = 0; y < state.widget.years.length; y++) ...[
              if (y > 0) const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${state.widget.years[y]}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (var m = 0; m <= 12; m++)
                    _ReturnsCell(
                      width: cellWidth,
                      cellKey: 'beui-returns-cell-$y-$m',
                      semanticLabel:
                          '${state.widget.years[y]} ${months[m]} return ${beuiChartSignedPercent(state._value(state._cell(y, m)))}',
                      label: months[m],
                      value: state._value(state._cell(y, m)),
                      background: colors.background,
                      positive: colors.success,
                      negative: colors.destructive,
                      selected:
                          selection != null &&
                          y * 13 + m >= low &&
                          y * 13 + m <= high,
                      dimmed:
                          selection != null &&
                          !(y * 13 + m >= low && y * 13 + m <= high),
                      pressed:
                          selection != null &&
                          (state._cell(y, m) == selection.start ||
                              state._cell(y, m) == selection.end),
                      onTap: () => state._select(state._cell(y, m)),
                      tooltip: BeuiChartTooltipCard(
                        title: state._spanNote(state._cell(y, m)) == null
                            ? '${state.widget.years[y]} ${months[m]}'
                            : '${state.widget.years[y]} ${months[m]} span',
                        lines: [
                          beuiChartSignedPercent(
                            state._spanValue(state._cell(y, m)) ??
                                state._value(state._cell(y, m)),
                          ),
                          ?state._spanNote(state._cell(y, m)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReturnsCell extends StatelessWidget {
  const _ReturnsCell({
    required this.width,
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
  });
  final double width;
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
  @override
  Widget build(BuildContext context) {
    final tint = value >= 0 ? positive : negative;
    final intensity = (value.abs() / 12).clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      height: 34,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: BeuiChartTooltip(
          enabled: true,
          content: tooltip,
          child: Semantics(
            button: true,
            selected: pressed,
            label: semanticLabel,
            child: GestureDetector(
              key: ValueKey(cellKey),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: BeuiFocusRing(
                focused: pressed,
                borderRadius: BorderRadius.circular(4),
                child: BeuiChartSpring(
                  value: pressed ? 1.06 : 1,
                  builder: (context, scale) => Transform.scale(
                    scale: scale,
                    child: BeuiChartFade(
                      opacity: dimmed ? .25 : 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            tint.withValues(alpha: .08 + intensity * .55),
                            background,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: selected
                              ? Border.all(color: tint.withValues(alpha: .65))
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            beuiChartSignedPercent(value, digits: 0),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: tint,
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

/// Tooltip composition slot. Tooltips are hosted by individual month cells.
class BeuiReturnsCalendarTooltip extends StatelessWidget {
  /// Creates the tooltip slot.
  const BeuiReturnsCalendarTooltip({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
