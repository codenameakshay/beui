/// Monthly percentage returns with compounded year and range summaries.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../motion/_engine.dart';
import '../motion/_focus_ring.dart';
import '../motion/tooltip.dart';
import '../theme/beui_colors.dart';
import '../theme/beui_text_theme.dart';
import '../tokens/motion.dart';
import '_shared.dart';

// Preserve SPRING_PRESS physics and commit its exact source target at rest.
final _returnsPressSpring = SpringMotion(
  beuiSpringPress.description,
  snapToEnd: true,
);

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

/// Values supplied to a custom returns-calendar tooltip renderer.
@immutable
class BeuiReturnsCalendarTooltipData {
  /// Creates tooltip data for the currently inspected cell or span.
  const BeuiReturnsCalendarTooltipData({
    required this.label,
    required this.value,
    required this.note,
  });

  /// The month/year label or inclusive span label.
  final String label;

  /// The signed monthly, annual, or compounded span return in percent.
  final double value;

  /// Optional span length or annual note.
  final String? note;
}

/// Calendar of monthly investment returns, with compounded year totals.
class BeuiReturnsCalendar extends StatefulWidget {
  /// Creates a returns calendar.
  const BeuiReturnsCalendar({
    super.key,
    this.years = const [],
    this.returns = const [],
    this.selection,
    this.selectionIsControlled = false,
    this.defaultSelection,
    this.onSelectionChange,
    this.tooltipBuilder,
    this.child,
  });

  /// Row labels, one per row of [returns].
  final List<int> years;

  /// `returns[year][month]` percentages, twelve months per row.
  final List<List<double>> returns;

  /// Controlled selection.
  final BeuiReturnsCalendarSelection? selection;

  /// Treats [selection] as controlled even when it is explicitly null.
  ///
  /// A non-null [selection] is controlled regardless of this flag. This
  /// additive flag represents React's `selection={null}` separately from an
  /// omitted selection without changing the established nullable API.
  final bool selectionIsControlled;

  /// Initial uncontrolled selection.
  final BeuiReturnsCalendarSelection? defaultSelection;

  /// Reports user selection changes.
  final ValueChanged<BeuiReturnsCalendarSelection?>? onSelectionChange;

  /// Replaces the default tooltip body while retaining the shared BeuiTooltip
  /// overlay, placement, dismissal and reduced-motion behavior.
  final Widget Function(
    BuildContext context,
    BeuiReturnsCalendarTooltipData data,
  )?
  tooltipBuilder;

  /// Custom composition. Defaults to the grid.
  final Widget? child;

  @override
  State<BeuiReturnsCalendar> createState() => _BeuiReturnsCalendarState();
}

class _BeuiReturnsCalendarState extends State<BeuiReturnsCalendar>
    with BeuiChartActiveState<BeuiReturnsCalendar>, BeuiChartInspectorKeys {
  final _gridFocus = FocusNode(skipTraversal: true);
  final _cellFocus = <((int, int), int), FocusNode>{};
  final _tooltipAnchors = <((int, int), int), _ReturnsTooltipAnchor>{};
  Timer? _entranceTimer;
  bool _entranceSettled = false;

  void _scheduleEntranceSettlement() {
    _entranceTimer?.cancel();
    _entranceSettled = false;
    _entranceTimer = Timer(
      Duration(milliseconds: (widget.years.length + 13) * 20 + 500),
      () {
        if (mounted) setState(() => _entranceSettled = true);
      },
    );
  }

  List<(int, int)> _rowIdentities(List<int> years) {
    final occurrences = <int, int>{};
    return [
      for (final year in years)
        (
          year,
          occurrences.update(year, (count) => count + 1, ifAbsent: () => 0),
        ),
    ];
  }

  int? _removedRow;

  void _removedFocusedCell(int row) {
    if (row >= widget.years.length) return;
    _removedRow = row;
    _gridFocus.requestFocus();
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    _gridFocus.dispose();
    _tooltipAnchors.clear();
    super.dispose();
  }

  BeuiReturnsCalendarCell? _rangeEnd;
  BeuiReturnsCalendarCell? _hover;
  bool _keyboardFocusVisible = false;
  BeuiReturnsCalendarCell? _dismissed;
  BeuiReturnsCalendarCell? get _hot =>
      _hover ?? _selection?.end ?? _selection?.start;
  BeuiReturnsCalendarCell? get _tip =>
      _selection?.end ?? _hover ?? _selection?.start;
  void _dismiss(BeuiReturnsCalendarCell cell) =>
      setState(() => _dismissed = cell);
  void _setHover(BeuiReturnsCalendarCell? cell) => setState(() {
    if (_hover != cell) _dismissed = null;
    _hover = cell;
  });
  void _setPointerHover(BeuiReturnsCalendarCell? cell) => setState(() {
    _keyboardFocusVisible = false;
    if (_hover != cell) _dismissed = null;
    _hover = cell;
  });
  void _setFocus(BeuiReturnsCalendarCell cell, bool focused) => setState(() {
    _keyboardFocusVisible =
        focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (focused) {
      if (_hover != cell) _dismissed = null;
      _hover = cell;
    } else if (_hover == cell) {
      _hover = null;
    }
  });
  void _markKeyboardInput() {
    if (_keyboardFocusVisible) return;
    setState(() => _keyboardFocusVisible = true);
  }

  void _markPointerInput() {
    if (!_keyboardFocusVisible) return;
    setState(() => _keyboardFocusVisible = false);
  }

  _ReturnsTooltipAnchor _tooltipAnchor(BeuiReturnsCalendarCell cell) =>
      _tooltipAnchors.putIfAbsent((
        _rowIdentities(widget.years)[cell.year],
        cell.month,
      ), _ReturnsTooltipAnchor.new);

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
  ValueChanged<String?>? get widgetOnActiveChange =>
      (id) => widget.onSelectionChange?.call(
        id == null ? null : BeuiReturnsCalendarSelection(start: _fromId(id)!),
      );
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
    _scheduleEntranceSettlement();
  }

  @override
  void didUpdateWidget(covariant BeuiReturnsCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.years.length != widget.years.length) {
      _scheduleEntranceSettlement();
    }
    final previousRows = _rowIdentities(oldWidget.years);
    final currentRows = _rowIdentities(widget.years).toSet();
    _tooltipAnchors.removeWhere(
      (identity, _) => !currentRows.contains(identity.$1),
    );
    for (var row = 0; row < previousRows.length; row++) {
      if (currentRows.contains(previousRows[row])) continue;
      for (var month = 0; month <= 12; month++) {
        final focus = _cellFocus[(previousRows[row], month)];
        if (focus?.hasPrimaryFocus ?? false) {
          // Clear scope history before detachment can restore an outside control.
          focus!.unfocus();
          _removedFocusedCell(row);
        }
      }
    }
    if (_hover != null && _hover!.year >= widget.years.length) _hover = null;
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
      final years = (selected.start.year - end.year).abs() + 1;
      return years > 1 ? '$years years' : null;
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
    final requested = _isControlled
        ? widget.selection
        : super.activeId == null
        ? null
        : BeuiReturnsCalendarSelection(
            start: _fromId(super.activeId)!,
            end: _rangeEnd,
          );
    if (requested == null || !_validCell(requested.start)) return null;
    final end = requested.end;
    if (end != null &&
        (!_validCell(end) ||
            (requested.start.month == 12) != (end.month == 12))) {
      return null;
    }
    return requested;
  }

  bool _validCell(BeuiReturnsCalendarCell cell) =>
      cell.year >= 0 &&
      cell.year < widget.years.length &&
      cell.month >= 0 &&
      cell.month <= 12;

  bool _includesMonth(BeuiReturnsCalendarSelection? selection, int y, int m) {
    if (selection == null) return false;
    if (selection.start.month == 12) {
      return _includesYearRow(selection, y);
    }
    final end = selection.end ?? selection.start;
    final startIndex = selection.start.year * 12 + selection.start.month;
    final endIndex = end.year * 12 + end.month;
    final low = startIndex < endIndex ? startIndex : endIndex;
    final high = startIndex > endIndex ? startIndex : endIndex;
    final index = y * 12 + m;
    return index >= low && index <= high;
  }

  bool _includesYearRow(BeuiReturnsCalendarSelection? selection, int y) {
    if (selection == null) return false;
    final end = selection.end ?? selection.start;
    final low = selection.start.year < end.year
        ? selection.start.year
        : end.year;
    final high = selection.start.year > end.year
        ? selection.start.year
        : end.year;
    return y >= low && y <= high;
  }

  bool _isSelectionEndpoint(
    BeuiReturnsCalendarSelection? selection,
    int y,
    int m,
  ) =>
      selection != null &&
      (selection.start == _cell(y, m) || selection.end == _cell(y, m));

  bool get _isControlled =>
      widget.selectionIsControlled || widget.selection != null;

  @override
  void setActiveId(String? id) {
    if (id == null) _rangeEnd = null;
    if (_isControlled) {
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
      if (!_isControlled) {
        _rangeEnd = cell;
        setState(() {});
      }
      widget.onSelectionChange?.call(next);
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: _ReturnsCalendarScope(
      state: this,
      child: Semantics(
        container: true,
        label: 'Returns calendar',
        child:
            widget.child ??
            const BeuiReturnsCalendarGrid(child: BeuiReturnsCalendarTooltip()),
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

class _ReturnsTooltipAnchor {
  final key = GlobalKey();
  final link = LayerLink();
}

class _ReturnsCalendarTooltipConfig extends InheritedWidget {
  const _ReturnsCalendarTooltipConfig({
    required this.builder,
    required super.child,
  });

  final Widget Function(
    BuildContext context,
    BeuiReturnsCalendarTooltipData data,
  )?
  builder;

  @override
  bool updateShouldNotify(_ReturnsCalendarTooltipConfig oldWidget) =>
      builder != oldWidget.builder;
}

bool _returnsCalendarCanHover() {
  if (kIsWeb) return RendererBinding.instance.mouseTracker.mouseIsConnected;
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.linux ||
    TargetPlatform.windows => true,
    _ => false,
  };
}

/// Month cells and compounded year totals.
class BeuiReturnsCalendarGrid extends StatelessWidget {
  /// Creates the returns grid.
  const BeuiReturnsCalendarGrid({
    super.key,
    this.cellWidth,
    this.child,
    this.tooltipBuilder,
  });

  /// Optional fixed month width. Otherwise the twelve months fill the row.
  final double? cellWidth;

  /// Composition slot, commonly [BeuiReturnsCalendarTooltip].
  final Widget? child;

  /// Optional cell tooltip renderer for this composition.
  final Widget Function(
    BuildContext context,
    BeuiReturnsCalendarTooltipData data,
  )?
  tooltipBuilder;

  @override
  Widget build(BuildContext context) {
    final state = _ReturnsCalendarScope.of(context);
    final colors = BeuiColors.resolve(context);
    final typography = const BeuiTextTheme();
    final gridChild =
        child ??
        (state.widget.tooltipBuilder != null || tooltipBuilder != null
            ? const BeuiReturnsCalendarTooltip()
            : null);
    final rows = state._rowIdentities(state.widget.years);
    final selection = state._preview;
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
            focusNode: state._gridFocus,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) state._markKeyboardInput();
              final row = state._removedRow;
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.tab &&
                  row != null &&
                  state._gridFocus.hasPrimaryFocus) {
                state._removedRow = null;
                final backwards = HardwareKeyboard.instance.isShiftPressed;
                final nextRow = backwards ? row - 1 : row;
                if (nextRow >= 0 && nextRow < state.widget.years.length) {
                  state._cellFocus[(rows[nextRow], backwards ? 12 : 0)]
                      ?.requestFocus();
                  return KeyEventResult.handled;
                }
              }
              if (event is KeyDownEvent &&
                  const [
                    LogicalKeyboardKey.arrowRight,
                    LogicalKeyboardKey.arrowLeft,
                    LogicalKeyboardKey.arrowUp,
                    LogicalKeyboardKey.arrowDown,
                    LogicalKeyboardKey.home,
                    LogicalKeyboardKey.end,
                    LogicalKeyboardKey.pageUp,
                    LogicalKeyboardKey.pageDown,
                  ].contains(event.logicalKey)) {
                // The source uses native Tab order; navigation keys do not
                // turn this collection of buttons into a roving-focus grid.
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
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: typography.sansFamily,
                              fontFamilyFallback: typography.sansFamilyFallback,
                              fontSize: 10,
                              color: state._hot?.month == m
                                  ? colors.foreground
                                  : colors.mutedForeground,
                            ),
                            child: Text(months[m]),
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
                    key: ValueKey(rows[y]),
                    children: [
                      SizedBox(
                        width: 32,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: typography.monoFamily,
                              fontFamilyFallback: typography.monoFamilyFallback,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: state._hot?.year == y
                                  ? colors.foreground
                                  : colors.mutedForeground,
                            ),
                            textAlign: TextAlign.right,
                            child: Text(
                              _returnsYearLabel(state.widget.years[y]),
                            ),
                          ),
                        ),
                      ),
                      for (var m = 0; m <= 12; m++) ...[
                        const SizedBox(width: 4),
                        _ReturnsCell(
                          focusNodes: state._cellFocus,
                          tooltipAnchor: state._tooltipAnchor(
                            state._cell(y, m),
                          ),
                          identity: (rows[y], m),
                          width: m == 12 ? 52 : monthWidth,
                          height: monthWidth,
                          cellKey: 'beui-returns-cell-$y-$m',
                          semanticLabel: m == 12
                              ? '${state.widget.years[y]} ${beuiChartSignedPercent(state._value(state._cell(y, m)))} for the year'
                              : '${monthNames[m]} ${state.widget.years[y]} ${beuiChartSignedPercent(state._value(state._cell(y, m)))}',
                          label: monthNames[m],
                          delay: Duration(
                            milliseconds: (y + (m == 12 ? 13 : m)) * 20,
                          ),
                          annual: m == 12,
                          hot: state._hot == state._cell(y, m),
                          canHover: _returnsCalendarCanHover(),
                          settled:
                              state._entranceSettled ||
                              MediaQuery.disableAnimationsOf(context),
                          sweep:
                              state._hot == state._cell(y, 12) &&
                              selection?.start.month != 12,
                          sweepDelay: Duration(milliseconds: m * 35),
                          onHover: (hover) => state._setPointerHover(
                            hover ? state._cell(y, m) : null,
                          ),
                          onFocus: (focused) =>
                              state._setFocus(state._cell(y, m), focused),
                          keyboardFocusVisible: state._keyboardFocusVisible,
                          onPointerInteraction: state._markPointerInput,
                          value: state._value(state._cell(y, m)),
                          background: colors.background,
                          positive: colors.success,
                          negative: colors.destructive,
                          selected: state._isSelectionEndpoint(selection, y, m),
                          dimmed: selection != null
                              ? !(m == 12
                                    ? state._includesYearRow(selection, y)
                                    : state._includesMonth(selection, y, m))
                              : state._hot != null &&
                                    state._hot!.year != y &&
                                    (m == 12 || state._hot!.month != m),
                          pressed:
                              selection != null &&
                              (state._cell(y, m) == selection.start ||
                                  state._cell(y, m) == selection.end),
                          onTap: () => state._select(state._cell(y, m)),
                        ),
                      ],
                    ],
                  ),
                ],
                if (gridChild != null)
                  _ReturnsCalendarTooltipConfig(
                    builder: tooltipBuilder,
                    child: gridChild,
                  ),
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
    required this.focusNodes,
    required this.tooltipAnchor,
    required this.identity,
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
    required this.delay,
    required this.annual,
    required this.hot,
    required this.canHover,
    required this.settled,
    required this.keyboardFocusVisible,
    required this.onHover,
    required this.onFocus,
    required this.onPointerInteraction,
    required this.sweep,
    required this.sweepDelay,
  });
  final Map<((int, int), int), FocusNode> focusNodes;
  final _ReturnsTooltipAnchor tooltipAnchor;
  final ((int, int), int) identity;
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
  final Duration delay;
  final bool annual;
  final bool hot;
  final bool canHover;
  final bool settled;
  final bool keyboardFocusVisible;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocus;
  final VoidCallback onPointerInteraction;
  final bool sweep;
  final Duration sweepDelay;
  @override
  State<_ReturnsCell> createState() => _ReturnsCellState();
}

class _ReturnsCellState extends State<_ReturnsCell> {
  final _focus = FocusNode();
  bool _pointerPressed = false;
  int? _pressedPointer;

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton == 0 || _pressedPointer != null) return;
    _pressedPointer = event.pointer;
    widget.onPointerInteraction();
    if (!MediaQuery.disableAnimationsOf(context)) {
      setState(() => _pointerPressed = true);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _pressedPointer) return;
    _cancelPointerPress();
  }

  void _cancelPointerPress() {
    _pressedPointer = null;
    if (_pointerPressed) setState(() => _pointerPressed = false);
  }

  @override
  void initState() {
    super.initState();
    widget.focusNodes[widget.identity] = _focus;
  }

  @override
  void didUpdateWidget(covariant _ReturnsCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusNodes, widget.focusNodes) ||
        oldWidget.identity != widget.identity) {
      if (identical(oldWidget.focusNodes[oldWidget.identity], _focus)) {
        oldWidget.focusNodes.remove(oldWidget.identity);
      }
      widget.focusNodes[widget.identity] = _focus;
    }
  }

  @override
  void dispose() {
    if (identical(widget.focusNodes[widget.identity], _focus)) {
      widget.focusNodes.remove(widget.identity);
    }
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
      :tooltipAnchor,
      :delay,
      :annual,
      :hot,
      :canHover,
      :settled,
      :keyboardFocusVisible,
      :onHover,
      :onFocus,
      :onPointerInteraction,
      :sweep,
      :sweepDelay,
    ) = widget;
    final tint = value >= 0 ? positive : negative;
    final intensity = (value.abs() / 8).clamp(0.0, 1.0);
    final colors = BeuiColors.resolve(context);
    final typography = const BeuiTextTheme();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final keyboardFocus = _focus.hasFocus && keyboardFocusVisible;
    final tintOpacity = ((hot ? 24 : 8) + intensity * 55).round() / 100;
    final numeralOpacity = (85 + intensity * 15).round() / 100;
    final cellContents = _ReturnsWave(
      active: sweep && !annual,
      delay: sweepDelay,
      child: AnimatedOpacity(
        opacity: dimmed ? .35 : 1,
        duration: const Duration(milliseconds: 200),
        curve: beuiEaseOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: beuiEaseOut,
          decoration: BoxDecoration(
            color: annual
                ? hot
                      ? background
                      : colors.foreground.withValues(alpha: 0.06)
                : Color.alphaBlend(
                    tint.withValues(alpha: tintOpacity),
                    background,
                  ),
            borderRadius: BorderRadius.circular(4),
            border: selected
                ? Border.all(color: colors.foreground, width: 1.5)
                : annual && hot
                ? Border.all(color: colors.borderStrong)
                : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  _returnsCellLabel(label, value),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: typography.monoFamily,
                    fontFamilyFallback: typography.monoFamilyFallback,
                    fontSize: annual ? 11 : 9,
                    fontWeight: FontWeight.w500,
                    color: annual
                        ? _returnsCalendarInk(tint, colors)
                        : colors.foreground.withValues(alpha: numeralOpacity),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: hot && !selected ? 1 : 0,
                    duration: reduce && hot && !selected
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    curve: beuiEaseOut,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: tint, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final interactionScale = reduce
        ? 1.0
        : _pointerPressed
        ? (annual ? .96 : .92)
        : settled && hot && canHover && !annual
        ? 1.15
        : 1.0;
    final interaction = reduce
        ? Transform.scale(scale: 1, child: cellContents)
        : BeuiChartTween(
            value: interactionScale,
            from: 1,
            duration: const Duration(milliseconds: 300),
            motion: _returnsPressSpring,
            isMovement: true,
            builder: (context, scale) =>
                Transform.scale(scale: scale, child: cellContents),
          );
    final entrance = reduce
        ? interaction
        : BeuiChartTween(
            key: const ValueKey('returns-entrance-scale'),
            value: 1,
            from: annual ? 1 : .6,
            duration: const Duration(milliseconds: 300),
            delay: delay,
            motion: _returnsPressSpring,
            isMovement: true,
            builder: (context, scale) =>
                Transform.scale(scale: scale, child: interaction),
          );
    return SizedBox(
      width: width,
      height: height,
      child: CompositedTransformTarget(
        key: tooltipAnchor.key,
        link: tooltipAnchor.link,
        child: Semantics(
          button: true,
          selected: pressed,
          label: semanticLabel,
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerEnd,
            onPointerCancel: _handlePointerEnd,
            child: InkWell(
              focusNode: _focus,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTapCancel: _cancelPointerPress,
              onTap: () {
                _focus.requestFocus();
                onTap();
              },
              onHover: onHover,
              onFocusChange: onFocus,
              child: BeuiFocusRing(
                key: ValueKey(cellKey),
                focused: keyboardFocus,
                borderRadius: BorderRadius.circular(4),
                color: colors.focusRing,
                child: reduce
                    ? entrance
                    : BeuiChartTween(
                        value: 1,
                        from: 0,
                        duration: const Duration(milliseconds: 400),
                        delay: delay,
                        motion: annual
                            ? const CurvedMotion(
                                Duration(milliseconds: 400),
                                beuiEaseOut,
                              )
                            : _returnsPressSpring,
                        builder: (context, opacity) => Opacity(
                          opacity: opacity.clamp(0, 1),
                          child: entrance,
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

/// Mirrors the pinned source's light-theme `ink()` for its two fixed status
/// tokens. These literals were converted directly from source OKLCH
/// (`success: oklch(70% 0.18 155)`, `destructive: oklch(62% 0.22 25)`) with
/// light `--ink-l: 0.5`; dark mode uses the native token (`--ink-l: 1`).
///
/// Do not infer OKLCH from a BeuiColors sRGB value: it has already been
/// gamut-clipped and quantized. Consumer-overridden status colors are retained
/// unchanged because their original CSS color-space inputs are unavailable.
Color _returnsCalendarInk(Color source, BeuiColors colors) {
  if (colors.brightness != Brightness.light) return source;
  if (source == const Color(0xFF00BE6A) &&
      colors.success == const Color(0xFF00BE6A)) {
    return const Color(0xFF007E2F);
  }
  if (source == const Color(0xFFEE343B) &&
      colors.destructive == const Color(0xFFEE343B)) {
    return const Color(0xFFC20011);
  }
  return source;
}

/// Tooltip composition slot anchored to the calendar's active cell.
class BeuiReturnsCalendarTooltip extends StatelessWidget {
  /// Creates the tooltip slot.
  const BeuiReturnsCalendarTooltip({super.key, this.child, this.builder});

  /// Static tooltip content, matching the source `children` slot.
  final Widget? child;

  /// Dynamic tooltip content receiving the active label, value and note.
  final Widget Function(
    BuildContext context,
    BeuiReturnsCalendarTooltipData data,
  )?
  builder;

  @override
  Widget build(BuildContext context) {
    final state = _ReturnsCalendarScope.of(context);
    final config = context
        .dependOnInheritedWidgetOfExactType<_ReturnsCalendarTooltipConfig>();
    final cell = state._tip;
    final anchor = cell == null ? null : state._tooltipAnchor(cell);
    final value = cell == null
        ? 0.0
        : state._spanValue(cell) ?? state._value(cell);
    final data = cell == null
        ? null
        : BeuiReturnsCalendarTooltipData(
            label: state._tipLabel(cell),
            value: value,
            note:
                state._spanNote(cell) ??
                (cell.month == 12 ? 'for the year' : null),
          );
    final renderer = state.widget.tooltipBuilder ?? config?.builder ?? builder;
    final colors = BeuiColors.resolve(context);
    final typography = const BeuiTextTheme();
    final content = data == null
        ? const SizedBox.shrink()
        : renderer != null
        ? renderer(context, data)
        : child ??
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(color: colors.mutedForeground),
                  ),
                  BeuiChartTicker(
                    value: data.value.abs(),
                    duration: const Duration(milliseconds: 350),
                    style: TextStyle(
                      color: _returnsCalendarInk(
                        data.value >= 0 ? colors.success : colors.destructive,
                        colors,
                      ),
                      fontFamily: typography.monoFamily,
                      fontFamilyFallback: typography.monoFamilyFallback,
                    ),
                    format: (_) =>
                        '${data.value < 0 ? '−' : '+'}${data.value.abs().toStringAsFixed(1)}%',
                  ),
                  if (data.note case final note?)
                    Text(note, style: TextStyle(color: colors.mutedForeground)),
                ],
              );
    return BeuiTooltip(
      key: ValueKey(cell),
      content: content,
      open: cell != null && state._dismissed != cell,
      onOpenChange: (open) {
        if (!open && cell != null) state._dismiss(cell);
      },
      externalAnchor: anchor?.key,
      anchorLink: anchor?.link,
      delay: Duration.zero,
      child: const SizedBox.shrink(),
    );
  }
}
