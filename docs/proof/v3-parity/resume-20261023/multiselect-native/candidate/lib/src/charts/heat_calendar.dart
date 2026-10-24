/// UTC, Monday-first activity calendar with range selection and level filter.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../motion/_focus_ring.dart';
import '../theme/beui_colors.dart';
import '_shared.dart';

/// A zero-based week/day coordinate (Monday is day zero).
@immutable
class BeuiHeatCalendarCell {
  /// Creates a coordinate.
  const BeuiHeatCalendarCell({required this.week, required this.day});

  /// Zero-based week column.
  final int week;

  /// Zero-based weekday, Monday first.
  final int day;

  @override
  bool operator ==(Object other) =>
      other is BeuiHeatCalendarCell && week == other.week && day == other.day;

  @override
  int get hashCode => Object.hash(week, day);
}

/// A selected heat-calendar span. An omitted [end] is an anchored preview.
@immutable
class BeuiHeatCalendarSelection {
  /// Creates an anchored selection or a locked range.
  const BeuiHeatCalendarSelection({required this.start, this.end});

  /// First selected cell.
  final BeuiHeatCalendarCell start;

  /// Last selected cell, when the range has been locked.
  final BeuiHeatCalendarCell? end;

  @override
  bool operator ==(Object other) =>
      other is BeuiHeatCalendarSelection &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Composable daily activity grid. Intensities are clamped to 0–1.
class BeuiHeatCalendar extends StatefulWidget {
  /// Creates an activity calendar.
  const BeuiHeatCalendar({
    super.key,
    this.unit = 'commits',
    this.weeks = 16,
    this.maxCount = 14,
    this.values = const [],
    this.endDate,
    this.color,
    this.selection,
    this.defaultSelection,
    this.onSelectionChange,
    this.child,
  }) : assert(weeks > 0),
       assert(maxCount >= 0);

  /// Noun shown after each count.
  final String unit;

  /// Number of week columns.
  final int weeks;

  /// Count represented by intensity 1.
  final double maxCount;

  /// `values[week][day]` intensities. Missing entries are zero.
  final List<List<double>> values;

  /// Last UTC date. Defaults to the current UTC date.
  final DateTime? endDate;

  /// Optional CSS-style hex or beUI color token.
  final String? color;

  /// Controlled selection; null clears it.
  final BeuiHeatCalendarSelection? selection;

  /// Initial selection for uncontrolled use.
  final BeuiHeatCalendarSelection? defaultSelection;

  /// Called after a user selection change.
  final ValueChanged<BeuiHeatCalendarSelection?>? onSelectionChange;

  /// Custom composition. Defaults to grid, tooltip and legend.
  final Widget? child;

  @override
  State<BeuiHeatCalendar> createState() => _BeuiHeatCalendarState();
}

class _BeuiHeatCalendarState extends State<BeuiHeatCalendar>
    with BeuiChartActiveState<BeuiHeatCalendar>, BeuiChartInspectorKeys {
  BeuiHeatCalendarCell? _rangeEnd;
  BeuiHeatCalendarCell? _hover;
  BeuiHeatCalendarCell? _dismissed;
  final _focus = <String, FocusNode>{};
  int? _filter;
  bool _resumeAfterRemoval = false;
  final _focusScope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  BeuiHeatCalendarCell? get _tip =>
      _selection?.end ?? _hover ?? _selection?.start;
  BeuiHeatCalendarSelection? get _preview {
    final selection = _selection;
    return selection == null
        ? null
        : BeuiHeatCalendarSelection(
            start: selection.start,
            end: selection.end ?? _hover,
          );
  }

  void _setHover(BeuiHeatCalendarCell? cell) => setState(() {
    if (_hover != cell) _dismissed = null;
    _hover = cell;
  });
  void _dismiss(BeuiHeatCalendarCell cell) => setState(() => _dismissed = cell);

  @override
  void dispose() {
    _focusScope.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  String? get widgetActiveId => _encode(widget.selection?.start);
  @override
  String? get widgetDefaultActiveId => _encode(widget.defaultSelection?.start);
  @override
  ValueChanged<String?>? get widgetOnActiveChange => null;
  @override
  Iterable<String> get knownIds => inspectableIds;
  @override
  String? get activeId => widget.selection == null
      ? super.activeId
      : _encode(widget.selection!.start);
  @override
  List<String> get inspectableIds => [
    for (var w = 0; w < widget.weeks; w++)
      for (var d = 0; d < 7; d++)
        if (!_future(_cell(w, d))) _encode(_cell(w, d))!,
  ];

  @override
  void initState() {
    super.initState();
    initActive();
    _rangeEnd = widget.defaultSelection?.end;
  }

  @override
  void didUpdateWidget(covariant BeuiHeatCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hover != null && !_validCell(_hover!)) _hover = null;
    if (_dismissed != null && !_validCell(_dismissed!)) _dismissed = null;
    // Detaching a focused cell otherwise restores an earlier day from history.
    for (final entry in _focus.entries) {
      if (!_validCell(_decode(entry.key)!) && entry.value.hasFocus) {
        _resumeAfterRemoval = true;
        entry.value.unfocus();
      }
    }
    if (widget.selection == null &&
        (_rangeEnd != null && !_validCell(_rangeEnd!) ||
            super.activeId == null)) {
      setActiveId(null);
    }
    if (oldWidget.defaultSelection != widget.defaultSelection &&
        widget.selection == null &&
        oldWidget.selection == null) {
      setActiveId(_encode(widget.defaultSelection?.start));
      _rangeEnd = widget.defaultSelection?.end;
    }
  }

  String? _encode(BeuiHeatCalendarCell? c) =>
      c == null ? null : '${c.week}:${c.day}';
  BeuiHeatCalendarCell? _decode(String? id) {
    if (id == null) return null;
    final parts = id.split(':');
    if (parts.length != 2) return null;
    return BeuiHeatCalendarCell(
      week: int.tryParse(parts[0]) ?? -1,
      day: int.tryParse(parts[1]) ?? -1,
    );
  }

  BeuiHeatCalendarCell _cell(int w, int d) =>
      BeuiHeatCalendarCell(week: w, day: d);
  DateTime _utcEnd() {
    final date = (widget.endDate ?? DateTime.now()).toUtc();
    return DateTime.utc(date.year, date.month, date.day);
  }

  DateTime _startDate() {
    final end = _utcEnd();
    final monday = end.subtract(Duration(days: (end.weekday + 6) % 7));
    return monday.subtract(Duration(days: (widget.weeks - 1) * 7));
  }

  DateTime _date(BeuiHeatCalendarCell c) =>
      _startDate().add(Duration(days: c.week * 7 + c.day));
  bool _validCell(BeuiHeatCalendarCell c) =>
      c.week >= 0 &&
      c.week < widget.weeks &&
      c.day >= 0 &&
      c.day < 7 &&
      !_future(c);
  bool _future(BeuiHeatCalendarCell c) => _date(c).isAfter(_utcEnd());
  double _level(BeuiHeatCalendarCell c) =>
      ((widget.values.length > c.week && widget.values[c.week].length > c.day
                  ? widget.values[c.week][c.day]
                  : 0)
              .clamp(0.0, 1.0))
          .toDouble();
  int get _rangeTotal {
    final selected = _preview;
    final end = selected?.end;
    if (selected == null || end == null) return 0;
    final first = selected.start.week * 7 + selected.start.day;
    final last = end.week * 7 + end.day;
    var total = 0;
    for (
      var index = first < last ? first : last;
      index <= (first > last ? first : last);
      index++
    ) {
      final cell = _cell(index ~/ 7, index % 7);
      if (!_future(cell)) total += (_level(cell) * widget.maxCount).round();
    }
    return total;
  }

  BeuiHeatCalendarSelection? get _selection {
    if (widget.selection != null) {
      final selection = widget.selection!;
      return _validCell(selection.start) &&
              (selection.end == null || _validCell(selection.end!))
          ? selection
          : null;
    }
    final start = _decode(super.activeId);
    return start == null
        ? null
        : BeuiHeatCalendarSelection(start: start, end: _rangeEnd);
  }

  @override
  void setActiveId(String? id) {
    if (id == null) _rangeEnd = null;
    if (widget.selection != null) {
      widget.onSelectionChange?.call(
        id == null ? null : BeuiHeatCalendarSelection(start: _decode(id)!),
      );
      return;
    }
    super.setActiveId(id);
  }

  void _select(BeuiHeatCalendarCell cell) {
    _dismissed = null;
    if (_future(cell)) return;
    final selected = _selection;
    if (selected?.end != null) {
      _rangeEnd = null;
      setActiveId(null);
    } else if (selected == null) {
      setActiveId(_encode(cell));
    } else if (selected.start == cell) {
      setActiveId(null);
    } else {
      final next = BeuiHeatCalendarSelection(start: selected.start, end: cell);
      if (widget.selection == null) {
        _rangeEnd = cell;
        setState(() {});
      }
      widget.onSelectionChange?.call(next);
    }
  }

  void _setFilter(int? level) => setState(() => _filter = level);

  void _toggleFilter(int level) =>
      setState(() => _filter = _filter == level ? null : level);

  @override
  Widget build(BuildContext context) => _HeatCalendarScope(
    state: this,
    child: FocusScope(
      node: _focusScope,
      onFocusChange: (focused) {
        if (!focused) _resumeAfterRemoval = false;
      },
      onKeyEvent: (node, event) {
        if (!_resumeAfterRemoval ||
            !node.hasPrimaryFocus ||
            event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.tab) {
          return KeyEventResult.ignored;
        }
        _resumeAfterRemoval = false;
        // Set the traversal origin on Tab. Focus notifications are deferred,
        // so forward traversal only exposes the following control.
        final last = _focus[inspectableIds.last];
        if (last == null || last.context == null) return KeyEventResult.ignored;
        last.requestFocus();
        if (!HardwareKeyboard.instance.isShiftPressed) last.nextFocus();
        return KeyEventResult.handled;
      },
      child: Semantics(
        container: true,
        label: 'Activity calendar',
        child:
            widget.child ??
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiHeatCalendarGrid(),
                SizedBox(height: 12),
                BeuiHeatCalendarLegend(),
              ],
            ),
      ),
    ),
  );
}

class _HeatCalendarScope extends InheritedWidget {
  const _HeatCalendarScope({required this.state, required super.child});
  final _BeuiHeatCalendarState state;
  static _BeuiHeatCalendarState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_HeatCalendarScope>();
    assert(
      scope != null,
      'Heat calendar parts must be inside BeuiHeatCalendar.',
    );
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_HeatCalendarScope oldWidget) => true;
}

/// Month headings and the Monday-first heat cells.
class BeuiHeatCalendarGrid extends StatelessWidget {
  /// Creates the calendar grid.
  const BeuiHeatCalendarGrid({super.key, this.cellSize = 16});

  /// Visual cell width and height. The source default is 16.
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final state = _HeatCalendarScope.of(context);
    final colors = BeuiColors.resolve(context);
    final selected = state._preview;
    final anchor = selected?.start;
    final end = selected?.end ?? anchor;
    final lo = anchor == null || end == null
        ? -1
        : (anchor.week * 7 + anchor.day) < (end.week * 7 + end.day)
        ? anchor.week * 7 + anchor.day
        : end.week * 7 + end.day;
    final hi = anchor == null || end == null
        ? -1
        : (anchor.week * 7 + anchor.day) > (end.week * 7 + end.day)
        ? anchor.week * 7 + anchor.day
        : end.week * 7 + end.day;
    final color = beuiChartColor(state.widget.color, colors);
    final width = state.widget.weeks * 20 - 4;
    return SizedBox(
      width: width.toDouble(),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
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
              state.setActiveId(null);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (var w = 0; w < state.widget.weeks; w++)
                      SizedBox(
                        width: w == state.widget.weeks - 1
                            ? cellSize
                            : cellSize + 4,
                        height: 12,
                        child: _monthLabel(state, w),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              for (var d = 0; d < 7; d++) ...[
                if (d > 0) const SizedBox(height: 4),
                Row(
                  children: [
                    for (var w = 0; w < state.widget.weeks; w++) ...[
                      if (w > 0) const SizedBox(width: 4),
                      Builder(
                        builder: (context) {
                          final cell = state._cell(w, d);
                          if (state._future(cell)) {
                            return SizedBox(width: cellSize, height: cellSize);
                          }
                          final index = w * 7 + d;
                          final level = state._level(cell);
                          final bucket = (level * 5).floor().clamp(0, 4);
                          final opacity = const [
                            0.06,
                            .24,
                            .46,
                            .70,
                            .94,
                          ][bucket];
                          final filtered =
                              state._filter != null && state._filter != bucket;
                          final inRange = index >= lo && index <= hi;
                          final pressed =
                              selected != null &&
                              (cell == selected.start || cell == selected.end);
                          final date = state._date(cell);
                          final count = (level * state.widget.maxCount).round();
                          final first = selected == null
                              ? date
                              : state._date(selected.start);
                          final last = selected?.end == null
                              ? first
                              : state._date(selected!.end!);
                          final days = first.difference(last).inDays.abs() + 1;
                          final rangeStart = first.isBefore(last)
                              ? first
                              : last;
                          final rangeEnd = first.isBefore(last) ? last : first;
                          return Semantics(
                            // Native web Tab follows semantics, not FocusTraversalOrder.
                            sortKey: OrdinalSortKey(index.toDouble()),
                            child: SizedBox(
                              width: cellSize,
                              height: cellSize,
                              child: BeuiChartTooltip(
                                enabled: true,
                                open:
                                    state._tip == cell &&
                                    state._dismissed != cell,
                                onOpenChange: (open) {
                                  if (!open) state._dismiss(cell);
                                },
                                content: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    BeuiChartTicker(
                                      value: days > 1
                                          ? state._rangeTotal
                                          : count,
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      format: (value) =>
                                          value.round().toString(),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(state.widget.unit),
                                    const SizedBox(width: 6),
                                    Text(
                                      days > 1
                                          ? '${_month[rangeStart.month - 1]} ${rangeStart.day} – ${_month[rangeEnd.month - 1]} ${rangeEnd.day}'
                                          : '${_weekday[date.weekday - 1]}, ${_month[date.month - 1]} ${date.day}',
                                      style: TextStyle(
                                        color: colors.mutedForeground,
                                      ),
                                    ),
                                    if (days > 1)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Text(
                                          '$days days',
                                          style: TextStyle(
                                            color: colors.mutedForeground,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                child: Semantics(
                                  button: true,
                                  selected: pressed,
                                  label:
                                      '$count ${state.widget.unit} on ${_weekday[date.weekday - 1]}, ${_month[date.month - 1]} ${date.day}',
                                  child: FocusTraversalOrder(
                                    order: NumericFocusOrder(index.toDouble()),
                                    child: InkWell(
                                      key: ValueKey('beui-heat-cell-$w-$d'),
                                      focusNode: state._focus.putIfAbsent(
                                        '$w:$d',
                                        FocusNode.new,
                                      ),
                                      onHover: (on) =>
                                          state._setHover(on ? cell : null),
                                      onFocusChange: (on) =>
                                          state._setHover(on ? cell : null),
                                      onTap: () {
                                        state._focus['$w:$d']!.requestFocus();
                                        state._select(cell);
                                      },
                                      child: BeuiFocusRing(
                                        focused: pressed,
                                        borderRadius: BorderRadius.circular(3),
                                        child: BeuiChartSpring(
                                          value: pressed ? 1.12 : 1,
                                          builder: (context, scale) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: BeuiChartFade(
                                                  opacity: filtered ? .25 : 1,
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: bucket == 0
                                                          ? colors.foreground
                                                                .withValues(
                                                                  alpha: .06,
                                                                )
                                                          : color.withValues(
                                                              alpha: opacity,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            3,
                                                          ),
                                                      border: inRange
                                                          ? Border.all(
                                                              color: colors
                                                                  .foreground
                                                                  .withValues(
                                                                    alpha: .25,
                                                                  ),
                                                            )
                                                          : null,
                                                    ),
                                                    child:
                                                        const SizedBox.expand(),
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
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget? _monthLabel(_BeuiHeatCalendarState state, int week) {
    final date = state._startDate().add(Duration(days: week * 7));
    final previous = week == 0
        ? null
        : state._startDate().add(Duration(days: (week - 1) * 7));
    if (previous != null && previous.month == date.month) {
      return null;
    }
    return OverflowBox(
      maxWidth: 40,
      alignment: Alignment.centerLeft,
      child: Text(
        _month[date.month - 1],
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 10,
          color: BeuiColors.resolve(state.context).mutedForeground,
        ),
      ),
    );
  }
}

const _month = [
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
const _weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Legend levels, which also filter cells on activation.
class BeuiHeatCalendarLegend extends StatelessWidget {
  /// Creates the level legend.
  const BeuiHeatCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final state = _HeatCalendarScope.of(context);
    final colors = BeuiColors.resolve(context);
    final hue = beuiChartColor(state.widget.color, colors);
    final start = state._startDate();
    final end = state._utcEnd();
    final range =
        '${_month[start.month - 1]} ${start.day} – ${_month[end.month - 1]} ${end.day}';
    final gridWidth = state.widget.weeks * 20.0 - 4;
    final labelStyle = TextStyle(fontSize: 10, color: colors.mutedForeground);
    final scale = MouseRegion(
      onExit: (_) => state._setFilter(null),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('less', style: labelStyle),
          for (var level = 0; level < 5; level++)
            Semantics(
              button: true,
              selected: state._filter == level,
              label: 'Filter activity level $level',
              child: MouseRegion(
                onEnter: (_) => state._setFilter(level),
                child: FocusableActionDetector(
                  onFocusChange: (focused) =>
                      state._setFilter(focused ? level : null),
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                  },
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        state._toggleFilter(level);
                        return null;
                      },
                    ),
                  },
                  child: GestureDetector(
                    onTap: () => state._toggleFilter(level),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: level == 0
                              ? colors.foreground.withValues(alpha: .06)
                              : hue.withValues(
                                  alpha: const [0.0, .24, .46, .70, .94][level],
                                ),
                          borderRadius: BorderRadius.circular(3),
                          border: state._filter == level
                              ? Border.all(color: colors.foreground)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Text('more', style: labelStyle),
        ],
      ),
    );
    final rangeLabel = Text(range, style: labelStyle);
    if (gridWidth < 280) {
      return Wrap(spacing: 16, children: [rangeLabel, scale]);
    }
    return SizedBox(
      width: gridWidth,
      child: Row(children: [rangeLabel, const Spacer(), scale]),
    );
  }
}

/// Tooltip composition slot; cell tooltips are anchored to selected cells.
class BeuiHeatCalendarTooltip extends StatelessWidget {
  /// Creates the tooltip slot.
  const BeuiHeatCalendarTooltip({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
