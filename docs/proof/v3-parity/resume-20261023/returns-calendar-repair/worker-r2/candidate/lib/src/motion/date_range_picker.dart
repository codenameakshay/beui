import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show NoMotion, SingleMotionBuilder;

const int _dayMs = Duration.millisecondsPerDay;
const double _calendarWidth = 320;

/// Side of the trigger on which the date panel is placed.
enum BeuiDateRangePickerSide { bottom, top }

/// Horizontal alignment of the date panel relative to its trigger.
enum BeuiDateRangePickerAlignment { start, end }

/// A calendar date range. Dates are ISO-8601 calendar strings (`YYYY-MM-DD`)
/// so selecting a day never depends on the device's time zone.
@immutable
class BeuiDateRange {
  /// Creates a range from [from] through the optional [to] date.
  const BeuiDateRange({required this.from, this.to});

  /// Inclusive first day of the range.
  final String from;

  /// Inclusive final day. Null means the user is still choosing an end date.
  final String? to;

  @override
  bool operator ==(Object other) =>
      other is BeuiDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// A named quick-select range for [BeuiDateRangePicker].
@immutable
class BeuiDateRangePreset {
  /// Creates a preset with an accessible [label] and [value].
  const BeuiDateRangePreset({required this.label, required this.value});

  /// The text shown on the preset button and announced when selected.
  final String label;

  /// The date range selected by this preset.
  final BeuiDateRange value;
}

/// Composable date-range calendar, either inline or anchored to a popover.
///
/// Pass [value] and [onChanged] for controlled state, or omit [value] and seed
/// [defaultValue] for internal state. Dates and bounds use `YYYY-MM-DD`.
/// Supply [children] to compose [BeuiDateRangePickerTrigger] and
/// [BeuiDateRangePickerContent]; with no children, an inline calendar is shown.
class BeuiDateRangePicker extends StatefulWidget {
  /// Creates a date-range picker.
  const BeuiDateRangePicker({
    this.value,
    this.defaultValue,
    this.onChanged,
    this.defaultMonth,
    this.min,
    this.max,
    this.isDateDisabled,
    this.presets = const <BeuiDateRangePreset>[],
    this.locale = 'en-US',
    this.label = 'Choose a date range',
    this.enabled = true,
    this.autoFocus = false,
    this.showSummary = true,
    this.closeOnSelect = false,
    this.open,
    this.defaultOpen = false,
    this.onOpenChanged,
    this.children,
    super.key,
  });

  /// Controlled range. Null is a valid controlled empty value; use
  /// [defaultValue] for an uncontrolled picker.
  final BeuiDateRange? value;

  /// Initial range in uncontrolled mode.
  final BeuiDateRange? defaultValue;

  /// Called after a range changes or is cleared.
  final ValueChanged<BeuiDateRange?>? onChanged;

  /// Initial visible date; defaults to the selected start or today.
  final String? defaultMonth;

  /// Earliest selectable day, inclusive.
  final String? min;

  /// Latest selectable day, inclusive.
  final String? max;

  /// Returns true for dates that cannot be selected.
  final bool Function(String date)? isDateDisabled;

  /// Optional quick-select ranges displayed in the footer.
  final List<BeuiDateRangePreset> presets;

  /// Locale used for month names and accessible date labels.
  final String locale;

  /// Accessible name for the calendar and trigger.
  final String label;

  /// Whether the picker can be changed or opened.
  final bool enabled;

  /// Move focus to the active date after the inline calendar mounts.
  final bool autoFocus;

  /// Whether the start/end summary is shown in the default calendar.
  final bool showSummary;

  /// Close the popover after a full range or preset is selected.
  final bool closeOnSelect;

  /// Controlled popover state. Null selects uncontrolled mode.
  final bool? open;

  /// Initial popover state in uncontrolled mode.
  final bool defaultOpen;

  /// Called when the popover opens or closes.
  final ValueChanged<bool>? onOpenChanged;

  /// Composed trigger/content parts. Omit for an inline calendar.
  final List<Widget>? children;

  @override
  State<BeuiDateRangePicker> createState() => _BeuiDateRangePickerState();
}

class _BeuiDateRangePickerState extends State<BeuiDateRangePicker> {
  late BeuiDateRange? _internalValue = widget.defaultValue;
  late bool _internalOpen = widget.defaultOpen;
  late bool _valueControlled;
  late String _month = _monthOf(
    widget.defaultMonth ?? widget.defaultValue?.from ?? _todayIso(),
  );
  late String _cursor =
      widget.defaultValue?.from ?? widget.defaultMonth ?? _todayIso();
  String? _preview;
  String _announcement = '';
  final FocusNode _calendarFocus = FocusNode(debugLabel: 'date range calendar');

  bool get _controlled => _valueControlled;
  BeuiDateRange? get _value => _controlled ? widget.value : _internalValue;
  bool get _isOpen => widget.open ?? _internalOpen;

  @override
  void initState() {
    super.initState();
    _valueControlled =
        widget.value != null ||
        (widget.onChanged != null && widget.defaultValue == null);
    _validateProps(widget);
    if (widget.min != null && _month.compareTo(_monthOf(widget.min!)) < 0) {
      _month = _monthOf(widget.min!);
      _cursor = widget.min!;
    }
    if (widget.max != null && _month.compareTo(_monthOf(widget.max!)) > 0) {
      _month = _monthOf(widget.max!);
      _cursor = widget.max!;
    }
    if ((widget.autoFocus && widget.children == null) ||
        (_isOpen && _autoFocusContent)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _calendarFocus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant BeuiDateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) _valueControlled = true;
    _validateProps(widget);
    if (oldWidget.defaultMonth != widget.defaultMonth &&
        widget.defaultMonth != null) {
      _month = _monthOf(widget.defaultMonth!);
    }
  }

  @override
  void dispose() {
    _calendarFocus.dispose();
    super.dispose();
  }

  void _validateProps(BeuiDateRangePicker props) {
    if (props.min != null) _parseDate(props.min!);
    if (props.max != null) _parseDate(props.max!);
    if (props.defaultMonth != null) _parseDate(props.defaultMonth!);
    if (props.min != null &&
        props.max != null &&
        props.min!.compareTo(props.max!) > 0) {
      throw ArgumentError('Date range picker min must not exceed max.');
    }
    final value = props.value ?? props.defaultValue;
    if (value != null) {
      _parseDate(value.from);
      if (value.to != null) {
        _parseDate(value.to!);
        if (value.to!.compareTo(value.from) < 0) {
          throw ArgumentError('Date range must be ordered.');
        }
      }
    }
  }

  bool _unavailable(String date) {
    return !widget.enabled ||
        (widget.min != null && date.compareTo(widget.min!) < 0) ||
        (widget.max != null && date.compareTo(widget.max!) > 0) ||
        (widget.isDateDisabled?.call(date) ?? false);
  }

  bool _rangeAvailable(BeuiDateRange range) {
    final end = range.to ?? range.from;
    if (end.compareTo(range.from) < 0 ||
        _unavailable(range.from) ||
        _unavailable(end)) {
      return false;
    }
    if (widget.isDateDisabled != null) {
      for (
        var date = _addDays(range.from, 1);
        date.compareTo(end) < 0;
        date = _addDays(date, 1)
      ) {
        if (_unavailable(date)) return false;
      }
    }
    return true;
  }

  void _setOpen(bool next) {
    if (!widget.enabled || next == _isOpen) return;
    if (widget.open == null) setState(() => _internalOpen = next);
    widget.onOpenChanged?.call(next);
    if (next) {
      setState(() {
        _month = _monthOf(_value?.from ?? widget.defaultMonth ?? _todayIso());
        _cursor = _value?.from ?? widget.defaultMonth ?? _todayIso();
        _preview = null;
        _announcement = '';
      });
      if (_autoFocusContent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _calendarFocus.requestFocus();
            for (final child in widget.children ?? const <Widget>[]) {
              if (child is BeuiDateRangePickerContent) {
                child.onOpenAutoFocus?.call(_calendarFocus);
              }
            }
          }
        });
      }
    }
  }

  void _change(BeuiDateRange? next) {
    if (!widget.enabled || (next != null && !_rangeAvailable(next))) return;
    if (!_controlled) setState(() => _internalValue = next);
    widget.onChanged?.call(next);
    setState(() => _preview = null);
    if (next?.to != null && widget.closeOnSelect && _isOpen) _setOpen(false);
  }

  void _selectDate(String date) {
    if (_unavailable(date)) return;
    setState(() => _cursor = date);
    final current = _value;
    if (current == null || current.to != null) {
      _change(BeuiDateRange(from: date));
      setState(
        () => _announcement =
            'Start date ${_formatFull(date)}. Choose an end date.',
      );
      return;
    }
    final range = date.compareTo(current.from) < 0
        ? BeuiDateRange(from: date, to: current.from)
        : BeuiDateRange(from: current.from, to: date);
    if (!_rangeAvailable(range)) {
      setState(
        () => _announcement =
            'This range includes unavailable dates. Choose another end date.',
      );
      return;
    }
    _change(range);
    setState(
      () => _announcement =
          '${_formatShort(range.from)} to ${_formatShort(range.to!)} selected.',
    );
  }

  void _moveMonth(int delta, {String? fromDate}) {
    final base = _parseDate(fromDate ?? _cursor);
    final target = DateTime.utc(base.year, base.month + delta, 1);
    final endDay = DateTime.utc(target.year, target.month + 1, 0).day;
    final day = base.day.clamp(1, endDay);
    final date = _iso(DateTime.utc(target.year, target.month, day));
    if ((widget.min != null && date.compareTo(widget.min!) < 0) ||
        (widget.max != null && date.compareTo(widget.max!) > 0)) {
      return;
    }
    setState(() {
      _month = _monthOf(date);
      _cursor = date;
      _preview = null;
    });
  }

  KeyEventResult _handleDateKey(FocusNode node, KeyEvent event, String date) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _setOpen(false);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _selectDate(_cursor);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _moveMonth(
        (event.logicalKey == LogicalKeyboardKey.pageUp ? -1 : 1) *
            (HardwareKeyboard.instance.isShiftPressed ? 12 : 1),
        fromDate: date,
      );
      return KeyEventResult.handled;
    }
    final weekday = _parseDate(date).weekday % 7;
    final offset = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowUp => -7,
      LogicalKeyboardKey.arrowDown => 7,
      LogicalKeyboardKey.home => -weekday,
      LogicalKeyboardKey.end => 6 - weekday,
      _ => null,
    };
    if (offset == null) return KeyEventResult.ignored;
    var next = _addDays(date, offset);
    if (event.logicalKey != LogicalKeyboardKey.home &&
        event.logicalKey != LogicalKeyboardKey.end) {
      final direction = offset.sign;
      var attempts = 0;
      while (_unavailable(next) && attempts++ < 366) {
        next = _addDays(next, direction);
        if ((widget.min != null && next.compareTo(widget.min!) < 0) ||
            (widget.max != null && next.compareTo(widget.max!) > 0)) {
          return KeyEventResult.handled;
        }
      }
    }
    if (_unavailable(next)) return KeyEventResult.handled;
    setState(() {
      _cursor = next;
      _month = _monthOf(next);
      _preview = _value != null && _value!.to == null ? next : null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_calendarFocus);
    });
    return KeyEventResult.handled;
  }

  String _formatFull(String date) => DateFormatters.full(context, date);
  String _formatShort(String date) => DateFormatters.short(context, date);

  @override
  Widget build(BuildContext context) {
    final supplied = widget.children;
    if (supplied == null) {
      return _withLocale(
        _scope(
          child: BeuiDateRangePickerCalendar(showSummary: widget.showSummary),
        ),
      );
    }
    Widget? trigger;
    BeuiDateRangePickerContent? contentPart;
    final other = <Widget>[];
    for (final child in supplied) {
      if (child is BeuiDateRangePickerTrigger) {
        trigger = child;
      } else if (child is BeuiDateRangePickerContent) {
        contentPart = child;
      } else {
        other.add(child);
      }
    }
    trigger ??= const BeuiDateRangePickerTrigger();
    final panel =
        contentPart ??
        BeuiDateRangePickerContent(
          child: BeuiDateRangePickerCalendar(showSummary: widget.showSummary),
        );
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return _withLocale(
      _scope(
        child: BeuiOverlay(
          open: _isOpen,
          barrier: true,
          barrierColor: const Color(0x00000000),
          barrierDismissible: true,
          trapFocus: false,
          onDismiss: () => _setOpen(false),
          enterDuration: Duration(milliseconds: reduce ? 160 : 230),
          exitDuration: Duration(milliseconds: reduce ? 120 : 150),
          overlayBuilder: (context, animation, link) =>
              CompositedTransformFollower(
                link: link,
                showWhenUnlinked: true,
                targetAnchor: panel.side == BeuiDateRangePickerSide.top
                    ? (panel.align == BeuiDateRangePickerAlignment.end
                              ? AlignmentDirectional.topEnd
                              : AlignmentDirectional.topStart)
                          .resolve(Directionality.of(context))
                    : (panel.align == BeuiDateRangePickerAlignment.end
                              ? AlignmentDirectional.bottomEnd
                              : AlignmentDirectional.bottomStart)
                          .resolve(Directionality.of(context)),
                followerAnchor: panel.side == BeuiDateRangePickerSide.top
                    ? (panel.align == BeuiDateRangePickerAlignment.end
                              ? AlignmentDirectional.bottomEnd
                              : AlignmentDirectional.bottomStart)
                          .resolve(Directionality.of(context))
                    : (panel.align == BeuiDateRangePickerAlignment.end
                              ? AlignmentDirectional.topEnd
                              : AlignmentDirectional.topStart)
                          .resolve(Directionality.of(context)),
                offset: Offset(
                  0,
                  panel.side == BeuiDateRangePickerSide.top
                      ? -panel.sideOffset
                      : panel.sideOffset,
                ),
                child: FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: reduce ? const AlwaysStoppedAnimation(1) : animation,
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: colors.background,
                      elevation: panel.shadow ? 14 : 0,
                      shadowColor: colors.foreground.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(panel.radius),
                      child: panel.child,
                    ),
                  ),
                ),
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final child in other) child,
              if (trigger case final BeuiDateRangePickerTrigger button)
                _trigger(button),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withLocale(Widget child) {
    final parts = widget.locale.replaceAll('_', '-').split('-');
    final locale = Locale.fromSubtags(
      languageCode: parts.first,
      countryCode: parts.length > 1 ? parts[1] : null,
    );
    return Localizations.override(
      context: context,
      locale: locale,
      child: child,
    );
  }

  Widget _scope({required Widget child}) =>
      _DateRangePickerScope(state: this, child: child);

  Widget _trigger(BeuiDateRangePickerTrigger trigger) =>
      _DateRangePickerScope(state: this, child: trigger);

  BeuiDateRange? get value => _value;
  String get month => _month;
  String get cursor => _cursor;
  String? get preview => _preview;
  String get announcement => _announcement;
  bool get isOpen => _isOpen;
  bool get canPrevious =>
      widget.min == null || _month.compareTo(_monthOf(widget.min!)) > 0;
  bool get canNext =>
      widget.max == null || _month.compareTo(_monthOf(widget.max!)) < 0;
  bool isDisabled(String date) => _unavailable(date);
  String formatFull(String date) => _formatFull(date);
  String formatShort(String date) => _formatShort(date);
  void selectDate(String date) => _selectDate(date);
  void previewDate(String date) {
    final current = _value;
    if (current == null || current.to != null || _unavailable(date)) return;
    final candidate = date.compareTo(current.from) < 0
        ? BeuiDateRange(from: date, to: current.from)
        : BeuiDateRange(from: current.from, to: date);
    if (_rangeAvailable(candidate)) setState(() => _preview = date);
  }

  void clearPreview() {
    if (_preview != null) setState(() => _preview = null);
  }

  void setOpen(bool open) => _setOpen(open);
  void clear() => _change(null);
  void moveMonth(int delta) => _moveMonth(delta);
  void chooseMonth(int month) {
    final current = _parseDate(_month);
    final next =
        '${current.year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    if (!canChooseMonth(next)) return;
    setState(() {
      _month = next;
      _cursor = next;
    });
  }

  void chooseYear(int year) {
    final current = _parseDate(_month);
    var next =
        '${year.toString().padLeft(4, '0')}-${current.month.toString().padLeft(2, '0')}-01';
    if (widget.min != null && next.compareTo(_monthOf(widget.min!)) < 0) {
      next = _monthOf(widget.min!);
    }
    if (widget.max != null && next.compareTo(_monthOf(widget.max!)) > 0) {
      next = _monthOf(widget.max!);
    }
    setState(() {
      _month = next;
      _cursor = _month;
    });
  }

  bool canChooseMonth(String date) =>
      widget.enabled &&
      !(widget.min != null && date.compareTo(_monthOf(widget.min!)) < 0) &&
      !(widget.max != null && date.compareTo(_monthOf(widget.max!)) > 0);

  void selectPreset(BeuiDateRangePreset preset) {
    if (!_rangeAvailable(preset.value)) return;
    _change(preset.value);
    setState(() {
      _month = _monthOf(preset.value.from);
      _cursor = preset.value.from;
      _announcement = '${preset.label} selected.';
    });
  }

  Widget buildCalendar({bool? showSummary, Widget? child}) => _CalendarSurface(
    state: this,
    showSummary: showSummary ?? widget.showSummary,
    child: child,
  );

  FocusNode get calendarFocus => _calendarFocus;
  KeyEventResult onDateKey(FocusNode node, KeyEvent event, String date) =>
      _handleDateKey(node, event, date);
  List<BeuiDateRangePreset> get presets => widget.presets;
  bool get _autoFocusContent {
    for (final child in widget.children ?? const <Widget>[]) {
      if (child is BeuiDateRangePickerContent) return child.autoFocus;
    }
    return true;
  }
}

/// Shared state for composed date-range picker parts.
class _DateRangePickerScope extends InheritedWidget {
  const _DateRangePickerScope({required this.state, required super.child});
  final _BeuiDateRangePickerState state;

  static _BeuiDateRangePickerState of(BuildContext context, String part) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_DateRangePickerScope>();
    assert(scope != null, '$part must be used inside BeuiDateRangePicker.');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_DateRangePickerScope oldWidget) => true;
}

/// Calendar surface. By default it includes the summary, header, grid, and footer.
class BeuiDateRangePickerCalendar extends StatelessWidget {
  /// Creates a calendar surface.
  const BeuiDateRangePickerCalendar({this.showSummary, this.child, super.key});

  /// Override the root's summary visibility for this calendar.
  final bool? showSummary;

  /// Optional custom composition instead of the default calendar parts.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final state = _DateRangePickerScope.of(
      context,
      'BeuiDateRangePickerCalendar',
    );
    return state.buildCalendar(showSummary: showSummary, child: child);
  }
}

class _CalendarSurface extends StatelessWidget {
  const _CalendarSurface({
    required this.state,
    required this.showSummary,
    this.child,
  });
  final _BeuiDateRangePickerState state;
  final bool showSummary;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final month = _parseDate(state.month);
    return Semantics(
      container: true,
      label: 'Calendar, ${DateFormatters.monthYear(context, state.month)}',
      child: Container(
        width: _calendarWidth,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            child ??
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (showSummary) _RangeSummary(state: state),
                  BeuiDateRangePickerHeader(),
                  const SizedBox(height: 4),
                  _DateGrid(state: state, month: month),
                  const SizedBox(height: 10),
                  BeuiDateRangePickerFooter(),
                  Semantics(
                    liveRegion: true,
                    label: state.announcement,
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

/// Accessible range summary shown above the calendar grid.
class BeuiDateRangePickerSummary extends StatelessWidget {
  /// Creates the summary.
  const BeuiDateRangePickerSummary({super.key});
  @override
  Widget build(BuildContext context) => _RangeSummary(
    state: _DateRangePickerScope.of(context, 'BeuiDateRangePickerSummary'),
  );
}

class _RangeSummary extends StatelessWidget {
  const _RangeSummary({required this.state});
  final _BeuiDateRangePickerState state;
  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final value = state.value;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.35),
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryDate(
              label: 'Start date',
              value: value == null
                  ? 'Select date'
                  : state.formatShort(value.from),
            ),
          ),
          Icon(
            LucideIcons.arrow_right,
            size: 14,
            color: colors.mutedForeground,
          ),
          Expanded(
            child: _SummaryDate(
              label: 'End date',
              value: value?.to == null
                  ? 'Select date'
                  : state.formatShort(value!.to!),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDate extends StatelessWidget {
  const _SummaryDate({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ],
  );
}

/// Month/year navigation header with direct month and year choices.
class BeuiDateRangePickerHeader extends StatelessWidget {
  /// Creates the calendar header.
  const BeuiDateRangePickerHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final state = _DateRangePickerScope.of(
      context,
      'BeuiDateRangePickerHeader',
    );
    final colors = BeuiColors.resolve(context);
    final month = _parseDate(state.month);
    return Row(
      children: <Widget>[
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 3,
            children: <Widget>[
              _ChoiceButton(
                label: DateFormatters.month(month.month),
                onSelected: (date) => _showChoices(context, state, date, true),
              ),
              _ChoiceButton(
                label: '${month.year}',
                onSelected: (date) => _showChoices(context, state, date, false),
              ),
            ],
          ),
        ),
        _HeaderIcon(
          label: 'Previous month',
          enabled: state.canPrevious,
          onPressed: () => state.moveMonth(-1),
          hoverColor: colors.muted,
        ),
        _HeaderIcon(
          label: 'Next month',
          enabled: state.canNext,
          onPressed: () => state.moveMonth(1),
          icon: LucideIcons.chevron_right,
          hoverColor: colors.muted,
        ),
        IconTheme(
          data: IconThemeData(color: colors.mutedForeground),
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showChoices(
    BuildContext context,
    _BeuiDateRangePickerState state,
    String date,
    bool monthChoices,
  ) {
    final current = _parseDate(state.month);
    if (monthChoices) {
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: 280,
            child: GridView.count(
              crossAxisCount: 3,
              children: List<Widget>.generate(12, (index) {
                final value =
                    '${current.year.toString().padLeft(4, '0')}-${(index + 1).toString().padLeft(2, '0')}-01';
                return TextButton(
                  onPressed: (!state.canChooseMonth(value))
                      ? null
                      : () {
                          state.chooseMonth(index + 1);
                          Navigator.pop(context);
                        },
                  child: Text(DateFormatters.month(index + 1)),
                );
              }),
            ),
          ),
        ),
      );
    } else {
      final minYear = state.widget.min == null
          ? current.year - 60
          : _parseDate(state.widget.min!).year;
      final maxYear = state.widget.max == null
          ? current.year + 60
          : _parseDate(state.widget.max!).year;
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: 280,
            child: GridView.count(
              crossAxisCount: 4,
              children: List<Widget>.generate(maxYear - minYear + 1, (index) {
                final year = minYear + index;
                return TextButton(
                  onPressed: () {
                    state.chooseYear(year);
                    Navigator.pop(context);
                  },
                  child: Text('$year'),
                );
              }),
            ),
          ),
        ),
      );
    }
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.onSelected});
  final String label;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => onSelected(label),
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 3),
        Icon(LucideIcons.chevron_down, size: 12),
      ],
    ),
  );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.label,
    required this.enabled,
    required this.onPressed,
    required this.hoverColor,
    this.icon = LucideIcons.chevron_left,
  });
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final Color hoverColor;
  final IconData icon;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: enabled ? onPressed : null,
    icon: Icon(icon, size: 17),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    style: IconButton.styleFrom(hoverColor: hoverColor),
  );
}

/// Six-week date grid with roving focus and full calendar key navigation.
class BeuiDateRangePickerGrid extends StatelessWidget {
  /// Creates a date grid.
  const BeuiDateRangePickerGrid({super.key});
  @override
  Widget build(BuildContext context) {
    final state = _DateRangePickerScope.of(context, 'BeuiDateRangePickerGrid');
    return _DateGrid(state: state, month: _parseDate(state.month));
  }
}

class _DateGrid extends StatelessWidget {
  const _DateGrid({required this.state, required this.month});
  final _BeuiDateRangePickerState state;
  final DateTime month;
  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final firstWeekday = DateTime.utc(month.year, month.month, 1).weekday % 7;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final value = state.value;
    final shownTo = value?.to ?? (value == null ? null : state.preview);
    final start = value?.from;
    final reduceMovement =
        motionFor(context, beuiSpringLayout, isMovement: true) is NoMotion;
    return Focus(
      focusNode: state.calendarFocus,
      onKeyEvent: (node, event) => state.onDateKey(node, event, state.cursor),
      child: MouseRegion(
        onExit: (_) => state.clearPreview(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: beuiEaseOut,
          switchOutCurve: beuiEaseOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: reduceMovement
                ? child
                : SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.045, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
          ),
          child: Semantics(
            key: ValueKey<String>(state.month),
            explicitChildNodes: true,
            child: Column(
              children: <Widget>[
                Row(
                  children: List<Widget>.generate(
                    7,
                    (i) => Expanded(
                      child: Center(
                        child: Text(
                          _weekday(context, i),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.mutedForeground),
                        ),
                      ),
                    ),
                  ),
                ),
                ...List<Widget>.generate(
                  6,
                  (week) => Row(
                    children: List<Widget>.generate(7, (weekday) {
                      final index = week * 7 + weekday - firstWeekday + 1;
                      if (index < 1 || index > days) {
                        return const Expanded(child: SizedBox(height: 40));
                      }
                      final date = _iso(
                        DateTime.utc(month.year, month.month, index),
                      );
                      final endpoint = date == start || date == value?.to;
                      final inRange =
                          start != null &&
                          date.compareTo(start) >= 0 &&
                          date.compareTo(shownTo ?? start) <= 0;
                      final disabled = state.isDisabled(date);
                      final today = date == _todayIso();
                      return Expanded(
                        child: Semantics(
                          selected:
                              value != null &&
                              date.compareTo(value.from) >= 0 &&
                              date.compareTo(value.to ?? value.from) <= 0,
                          button: true,
                          enabled: !disabled,
                          label: state.formatFull(date),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: SizedBox(
                              height: 36,
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  if (inRange)
                                    Positioned.fill(
                                      child: Container(
                                        color: colors.foreground.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: _CalendarDay(
                                      day: '$index',
                                      selected: endpoint,
                                      inRange: inRange,
                                      today: today,
                                      enabled: !disabled,
                                      focused: state.cursor == date,
                                      colors: colors,
                                      onPressed: () => state.selectDate(date),
                                      onPreview: () => state.previewDate(date),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _weekday(BuildContext context, int index) {
    return DateFormatters.weekday(context, index);
  }
}

class _CalendarDay extends StatefulWidget {
  const _CalendarDay({
    required this.day,
    required this.selected,
    required this.inRange,
    required this.today,
    required this.enabled,
    required this.focused,
    required this.colors,
    required this.onPressed,
    required this.onPreview,
  });
  final String day;
  final bool selected;
  final bool inRange;
  final bool today;
  final bool enabled;
  final bool focused;
  final BeuiColors colors;
  final VoidCallback onPressed;
  final VoidCallback onPreview;
  @override
  State<_CalendarDay> createState() => _CalendarDayState();
}

class _CalendarDayState extends State<_CalendarDay> {
  bool _pressed = false;
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scale = _pressed && !reduce ? 0.9 : 1.0;
    return Semantics(
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: widget.enabled
            ? (_) {
                setState(() => _hovered = true);
                widget.onPreview();
              }
            : null,
        onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onPressed : null,
          onTapDown: widget.enabled
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: SingleMotionBuilder(
            value: scale,
            motion: motionFor(context, beuiSpringPress, isMovement: true),
            builder: (context, value, child) =>
                Transform.scale(scale: reduce ? 1 : value, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.selected
                    ? widget.colors.foreground
                    : _hovered && !widget.inRange
                    ? widget.colors.muted
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: widget.focused
                    ? Border.all(color: widget.colors.ring, width: 2)
                    : null,
              ),
              child: Text(
                widget.day,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.selected
                      ? widget.colors.background
                      : widget.enabled
                      ? widget.colors.foreground
                      : widget.colors.mutedForeground.withValues(alpha: 0.4),
                  fontWeight: widget.selected || widget.today
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Footer containing selection status, clear control, and configured presets.
class BeuiDateRangePickerFooter extends StatelessWidget {
  /// Creates the footer.
  const BeuiDateRangePickerFooter({super.key});
  @override
  Widget build(BuildContext context) {
    final state = _DateRangePickerScope.of(
      context,
      'BeuiDateRangePickerFooter',
    );
    final colors = BeuiColors.resolve(context);
    return Column(
      children: <Widget>[
        Divider(height: 1, color: colors.border),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Expanded(child: BeuiDateRangePickerSelection()),
            BeuiDateRangePickerClear(),
          ],
        ),
        if (state.presets.isNotEmpty) const SizedBox(height: 8),
        if (state.presets.isNotEmpty) const BeuiDateRangePickerPresets(),
      ],
    );
  }
}

/// Selection status text for the footer or a custom calendar composition.
class BeuiDateRangePickerSelection extends StatelessWidget {
  /// Creates the selection status.
  const BeuiDateRangePickerSelection({this.child, super.key});

  /// Optional custom status content.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) return child!;
    final state = _DateRangePickerScope.of(
      context,
      'BeuiDateRangePickerSelection',
    );
    final value = state.value;
    final days = value?.to == null
        ? null
        : _parseDate(value!.to!).difference(_parseDate(value.from)).inDays + 1;
    return Text(
      days == null
          ? (value == null ? 'Choose a start date' : 'Choose an end date')
          : '$days ${days == 1 ? 'day' : 'days'} selected',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: BeuiColors.resolve(context).mutedForeground,
      ),
    );
  }
}

/// Configured quick-select ranges for a custom calendar composition.
class BeuiDateRangePickerPresets extends StatelessWidget {
  /// Creates the preset collection.
  const BeuiDateRangePickerPresets({this.children, super.key});

  /// Optional replacement preset buttons.
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final state = _DateRangePickerScope.of(
      context,
      'BeuiDateRangePickerPresets',
    );
    final buttons =
        children ??
        state.presets
            .map((preset) => BeuiDateRangePickerPreset(preset: preset))
            .toList();
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }
}

/// Clears the currently selected range.
class BeuiDateRangePickerClear extends StatelessWidget {
  /// Creates the clear button.
  const BeuiDateRangePickerClear({this.child, super.key});

  /// Optional replacement label.
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final state = _DateRangePickerScope.of(context, 'BeuiDateRangePickerClear');
    return TextButton(
      onPressed: state.value == null ? null : state.clear,
      style:
          TextButton.styleFrom(
            minimumSize: const Size(40, 30),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return BeuiColors.resolve(context).muted;
              }
              return null;
            }),
          ),
      child: child ?? const Text('Clear'),
    );
  }
}

/// Selects one configured date-range preset.
class BeuiDateRangePickerPreset extends StatelessWidget {
  /// Creates a preset button.
  const BeuiDateRangePickerPreset({
    required this.preset,
    this.child,
    super.key,
  });

  /// Range and accessible label for this preset.
  final BeuiDateRangePreset preset;

  /// Optional custom button content.
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final state = _DateRangePickerScope.of(
      context,
      'BeuiDateRangePickerPreset',
    );
    final colors = BeuiColors.resolve(context);
    final selected = state.value == preset.value;
    return Semantics(
      button: true,
      selected: selected,
      label: preset.label,
      child: TextButton(
        onPressed:
            state.isDisabled(preset.value.from) ||
                (preset.value.to != null && state.isDisabled(preset.value.to!))
            ? null
            : () => state.selectPreset(preset),
        style:
            TextButton.styleFrom(
              backgroundColor: selected
                  ? colors.foreground
                  : colors.muted.withValues(alpha: 0.55),
              foregroundColor: selected
                  ? colors.background
                  : colors.mutedForeground,
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) return colors.muted;
                return null;
              }),
            ),
        child: child ?? Text(preset.label),
      ),
    );
  }
}

/// Button that opens the date-range popover.
class BeuiDateRangePickerTrigger extends StatelessWidget {
  /// Creates the trigger.
  const BeuiDateRangePickerTrigger({
    this.placeholder = 'Select dates',
    this.child,
    super.key,
  });

  /// Text shown when there is no selected range.
  final String placeholder;

  /// Optional custom trigger contents.
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final state = _DateRangePickerScope.of(
      context,
      'BeuiDateRangePickerTrigger',
    );
    final colors = BeuiColors.resolve(context);
    final value = state.value;
    final sameYear =
        value?.to != null &&
        value!.from.substring(0, 4) == value.to!.substring(0, 4);
    final summary = value == null
        ? placeholder
        : '${sameYear ? MaterialLocalizations.of(context).formatShortMonthDay(_parseDate(value.from)) : state.formatShort(value.from)} – ${value.to == null ? 'Select end' : state.formatShort(value.to!)}';
    return Semantics(
      button: true,
      expanded: state.isOpen,
      label: '${state.widget.label}: $summary',
      child: OutlinedButton(
        onPressed: state.widget.enabled
            ? () => state.setOpen(!state.isOpen)
            : null,
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              maximumSize: const Size(double.infinity, 36),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colors.foreground,
              backgroundColor: colors.background,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered)
                    ? colors.muted.withValues(alpha: .4)
                    : Colors.transparent,
              ),
            ),
        child:
            child ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  LucideIcons.calendar_days,
                  size: 15,
                  color: colors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Text(
                  summary,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevron_down,
                  size: 13,
                  color: colors.mutedForeground,
                ),
              ],
            ),
      ),
    );
  }
}

/// Floating panel part for a trigger-based date-range picker.
class BeuiDateRangePickerContent extends StatelessWidget {
  /// Creates the popover content.
  const BeuiDateRangePickerContent({
    required this.child,
    this.autoFocus = true,
    this.side = BeuiDateRangePickerSide.bottom,
    this.align = BeuiDateRangePickerAlignment.start,
    this.sideOffset = 8,
    this.radius = 16,
    this.shadow = true,
    this.onOpenAutoFocus,
    super.key,
  });

  /// Content, usually a [BeuiDateRangePickerCalendar].
  final Widget child;

  /// Focus the active date after the panel opens. Defaults to true.
  final bool autoFocus;

  /// Which side of the trigger holds the panel.
  final BeuiDateRangePickerSide side;

  /// Horizontal alignment against the trigger.
  final BeuiDateRangePickerAlignment align;

  /// Gap between trigger and panel, in logical pixels.
  final double sideOffset;

  /// Corner radius of the floating surface.
  final double radius;

  /// Whether the floating surface has elevation.
  final bool shadow;

  /// Called after the panel opens and its active date is focused.
  final ValueChanged<FocusNode>? onOpenAutoFocus;

  @override
  Widget build(BuildContext context) => child;
}

/// Convenience trigger + popover composition.
class BeuiDateRangePickerDropdown extends StatelessWidget {
  /// Creates a dropdown date-range picker.
  const BeuiDateRangePickerDropdown({
    this.placeholder = 'Select dates',
    this.showSummary = false,
    this.autoFocus = true,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.defaultMonth,
    this.min,
    this.max,
    this.isDateDisabled,
    this.label = 'Choose a date range',
    this.presets = const <BeuiDateRangePreset>[],
    this.locale = 'en-US',
    this.enabled = true,
    this.closeOnSelect = false,
    this.open,
    this.defaultOpen = false,
    this.onOpenChanged,
    super.key,
  });

  /// Empty-state trigger label.
  final String placeholder;

  /// Whether the calendar includes a start/end summary.
  final bool showSummary;

  /// Focus the active date when the dropdown opens.
  final bool autoFocus;

  /// Controlled date range.
  final BeuiDateRange? value;

  /// Initial uncontrolled date range.
  final BeuiDateRange? defaultValue;

  /// Selection callback.
  final ValueChanged<BeuiDateRange?>? onChanged;

  /// Initial visible calendar month.
  final String? defaultMonth;

  /// Earliest allowed date.
  final String? min;

  /// Latest allowed date.
  final String? max;

  /// Returns true for dates unavailable to selection.
  final bool Function(String date)? isDateDisabled;

  /// Accessible picker label.
  final String label;

  /// Quick selection options.
  final List<BeuiDateRangePreset> presets;

  /// Locale used for visible and spoken dates.
  final String locale;

  /// Whether the trigger and calendar are enabled.
  final bool enabled;

  /// Close the popover after a complete range or preset is selected.
  final bool closeOnSelect;

  /// Controlled popover state.
  final bool? open;

  /// Initial popover state when uncontrolled.
  final bool defaultOpen;

  /// Called when the popover opens or closes.
  final ValueChanged<bool>? onOpenChanged;

  @override
  Widget build(BuildContext context) => BeuiDateRangePicker(
    value: value,
    defaultValue: defaultValue,
    onChanged: onChanged,
    defaultMonth: defaultMonth,
    min: min,
    max: max,
    isDateDisabled: isDateDisabled,
    label: label,
    presets: presets,
    locale: locale,
    enabled: enabled,
    closeOnSelect: closeOnSelect,
    open: open,
    defaultOpen: defaultOpen,
    onOpenChanged: onOpenChanged,
    showSummary: showSummary,
    autoFocus: autoFocus,
    children: <Widget>[
      BeuiDateRangePickerTrigger(placeholder: placeholder),
      BeuiDateRangePickerContent(
        autoFocus: autoFocus,
        child: BeuiDateRangePickerCalendar(showSummary: showSummary),
      ),
    ],
  );
}

/// Formatting helpers use Flutter's localized material date conventions.
abstract final class DateFormatters {
  static String monthYear(BuildContext context, String date) =>
      MaterialLocalizations.of(context).formatMonthYear(_parseDate(date));
  static String month(int month) => const <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
  static String short(BuildContext context, String date) {
    final day = _parseDate(date);
    final locale = MaterialLocalizations.of(context);
    return '${locale.formatShortMonthDay(day)}, ${locale.formatYear(day)}';
  }

  static String full(BuildContext context, String date) =>
      MaterialLocalizations.of(context).formatFullDate(_parseDate(date));
  static String weekday(BuildContext context, int index) =>
      MaterialLocalizations.of(context).narrowWeekdays[index];
}

DateTime _parseDate(String date) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    throw FormatException('Invalid calendar date: $date. Use YYYY-MM-DD.');
  }
  final parts = date.split('-').map(int.parse).toList();
  final value = DateTime.utc(parts[0], parts[1], parts[2]);
  if (value.year != parts[0] ||
      value.month != parts[1] ||
      value.day != parts[2]) {
    throw FormatException('Invalid calendar date: $date. Use YYYY-MM-DD.');
  }
  return value;
}

String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _monthOf(String date) => '${date.substring(0, 7)}-01';
String _addDays(String date, int days) =>
    _iso(_parseDate(date).add(Duration(milliseconds: days * _dayMs)));
String _todayIso() => _iso(DateTime.now().toUtc());
