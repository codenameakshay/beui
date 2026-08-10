import 'package:flutter/material.dart';

import '../../theme/beui_colors.dart';
import 'day_row.dart';
import 'types.dart';

export 'types.dart'
    show
        BeuiDayAvailability,
        BeuiDayKey,
        BeuiTimeRange,
        BeuiWeekAvailability,
        beuiDefaultWeek;

/// A weekly availability scheduler — the Flutter port of beUI's
/// `availability-scheduler` block.
///
/// Seven [DayRow]s (Monday → Sunday) separated by hairline dividers: each has a
/// [BeuiSwitch] enable toggle, editable `start – end` time ranges with
/// spring-animated add/remove ([beuiSpringLayout]), a per-day add button, and a
/// `CopyMenu` that copies a day's hours to any other days. The row and range
/// reflow, the time-select dropdown, the copy popover, and the icon-button press
/// feedback all match the source's springs and timings; the overlay surfaces
/// (time-select, copy-menu) render through the shared [BeuiOverlay] foundation.
///
/// **Controlled + uncontrolled**, mirroring the source: pass [value] +
/// [onChanged] to control it, or seed it with [defaultValue] (defaulting to
/// [beuiDefaultWeek]) and read edits through [onChanged]. [step] sets the
/// dropdown granularity in minutes (default 30 → 48 options).
///
/// Reduced motion drops the movement (row/range offset+blur, panel scale) and
/// keeps opacity/colour transitions, via each part's own resolver.
class BeuiAvailabilityScheduler extends StatefulWidget {
  /// Creates an availability scheduler.
  const BeuiAvailabilityScheduler({
    this.value,
    this.defaultValue,
    this.onChanged,
    this.step = 30,
    super.key,
  });

  /// Controlled week. When non-null the widget renders this and never mutates
  /// its own copy; drive updates through [onChanged].
  final BeuiWeekAvailability? value;

  /// Uncontrolled initial week (used only when [value] is null). Defaults to
  /// [beuiDefaultWeek].
  final BeuiWeekAvailability? defaultValue;

  /// Called with the full new week on every edit.
  final ValueChanged<BeuiWeekAvailability>? onChanged;

  /// Minutes between selectable times (source `step`, default 30).
  final int step;

  @override
  State<BeuiAvailabilityScheduler> createState() =>
      _BeuiAvailabilitySchedulerState();
}

class _BeuiAvailabilitySchedulerState extends State<BeuiAvailabilityScheduler> {
  late BeuiWeekAvailability _internal;
  late List<BeuiTimeOption> _options;
  int _copyCounter = 0;

  bool get _controlled => widget.value != null;
  BeuiWeekAvailability get _week => widget.value ?? _internal;

  @override
  void initState() {
    super.initState();
    _internal = _cloneWeek(widget.defaultValue ?? beuiDefaultWeek());
    _options = buildOptions(widget.step);
  }

  @override
  void didUpdateWidget(BeuiAvailabilityScheduler old) {
    super.didUpdateWidget(old);
    if (widget.step != old.step) _options = buildOptions(widget.step);
  }

  BeuiWeekAvailability _cloneWeek(BeuiWeekAvailability w) => {
    for (final e in w.entries)
      e.key: BeuiDayAvailability(
        enabled: e.value.enabled,
        ranges: List<BeuiTimeRange>.of(e.value.ranges),
      ),
  };

  void _commit(BeuiWeekAvailability next) {
    if (!_controlled) setState(() => _internal = next);
    widget.onChanged?.call(next);
  }

  void _setDay(BeuiDayKey day, BeuiDayAvailability next) {
    _commit(Map<BeuiDayKey, BeuiDayAvailability>.of(_week)..[day] = next);
  }

  void _copyDay(BeuiDayKey from, List<BeuiDayKey> targets) {
    final source = _week[from]!;
    final next = Map<BeuiDayKey, BeuiDayAvailability>.of(_week);
    for (final t in targets) {
      next[t] = BeuiDayAvailability(
        enabled: source.enabled,
        ranges: [
          for (final r in source.ranges)
            r.copyWith(id: '${t.name}-c${_copyCounter++}'),
        ],
      );
    }
    _commit(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final week = _week;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 576), // max-w-xl
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < BeuiDayKey.values.length; i++)
            // `divide-y`: a Container (not a DecoratedBox) so the 1px rule
            // occupies layout height the way a CSS border-top does.
            Container(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: colors.border)),
              ),
              child: DayRow(
                key: ValueKey(BeuiDayKey.values[i]),
                day: BeuiDayKey.values[i],
                state: week[BeuiDayKey.values[i]]!,
                options: _options,
                onChanged: (next) => _setDay(BeuiDayKey.values[i], next),
                onCopy: (targets) => _copyDay(BeuiDayKey.values[i], targets),
              ),
            ),
        ],
      ),
    );
  }
}
