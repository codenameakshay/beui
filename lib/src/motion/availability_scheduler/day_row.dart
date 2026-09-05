import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';
import '../switch.dart';
import '../tooltip.dart';
import 'copy_menu.dart';
import 'icon_button.dart';
import 'time_select.dart';
import 'types.dart';

/// Breakpoint mirroring the source `sm:` (640px): below it the row stacks and
/// the actions ride beside the toggle; at/above it the row is horizontal.
///
/// Tailwind `sm:` keys off the **viewport** width, not the element's own box
/// (the block is capped at `max-w-xl` = 576px yet still uses the horizontal
/// layout on desktop), so this reads [MediaQuery] rather than local constraints.
const double _smBreakpoint = 640;

/// One weekday's row — the Flutter port of the scheduler's `day-row.tsx`.
///
/// A [BeuiSwitch] + label lead the row; when enabled it lists the day's time
/// ranges (two [TimeSelect]s and a remove button each), otherwise a single
/// "Unavailable" line. Adding, removing, enabling and disabling animate the
/// slots on `SPRING_LAYOUT` ([beuiSpringLayout]): a range enters from
/// `opacity 0, y -6, blur 4px` and leaves to `opacity 0, y -4, blur 4px`, while
/// its occupied height rides the same progress so the rows below glide open or
/// closed (the source's `AnimatePresence mode="popLayout"` + `layout="position"`
/// reflow). The trailing actions are an add button and a [CopyMenu].
///
/// Unlike the source's `zIndex: depth` layering, the [TimeSelect] and [CopyMenu]
/// panels render through [BeuiOverlay] into the root overlay, so they always
/// paint above later rows without per-row stacking.
///
/// Internal to the scheduler — not part of the public surface.
class DayRow extends StatefulWidget {
  /// Creates a day row.
  const DayRow({
    required this.day,
    required this.state,
    required this.options,
    required this.onChanged,
    required this.onCopy,
    super.key,
  });

  /// The weekday this row edits.
  final BeuiDayKey day;

  /// This day's current availability.
  final BeuiDayAvailability state;

  /// Selectable time options for the [TimeSelect]s.
  final List<BeuiTimeOption> options;

  /// Emits the day's new availability on any edit.
  final ValueChanged<BeuiDayAvailability> onChanged;

  /// Copies this day's hours to [targets].
  final ValueChanged<List<BeuiDayKey>> onCopy;

  @override
  State<DayRow> createState() => _DayRowState();
}

/// A presence-tracked slot: a range (by [range]) or the "Unavailable" marker
/// (when [range] is null). Mirrors the toast-stack `_ToastEntry` contract:
/// vanished slots stay mounted, marked [exiting], until their exit spring
/// reports done.
class _Slot {
  _Slot({required this.key, this.range});
  final String key;
  BeuiTimeRange? range;
  bool exiting = false;
}

class _DayRowState extends State<DayRow> {
  final List<_Slot> _slots = [];
  int _idCounter = 0;

  String _nextId() => '${widget.day.name}-n${_idCounter++}';

  @override
  void initState() {
    super.initState();
    _reconcile();
  }

  @override
  void didUpdateWidget(DayRow old) {
    super.didUpdateWidget(old);
    _reconcile();
  }

  /// Diffs [_slots] against the desired set (ranges when enabled, else the
  /// unavailable marker), marking gone slots exiting and adding new ones.
  void _reconcile() {
    // Desired keys in order.
    final desired = <String, BeuiTimeRange?>{};
    if (widget.state.enabled) {
      for (final r in widget.state.ranges) {
        desired[r.id] = r;
      }
    } else {
      desired['unavailable'] = null;
    }

    // Mark exits / revive + update survivors.
    for (final slot in _slots) {
      if (desired.containsKey(slot.key)) {
        slot
          ..exiting = false
          ..range = desired[slot.key];
      } else {
        slot.exiting = true;
      }
    }
    // Append newcomers, preserving desired order among non-exiting slots.
    final known = {for (final s in _slots) s.key};
    for (final entry in desired.entries) {
      if (!known.contains(entry.key)) {
        _slots.add(_Slot(key: entry.key, range: entry.value));
      }
    }
  }

  void _onExited(_Slot slot) {
    if (!mounted) return;
    setState(() => _slots.remove(slot));
  }

  // ── edits (ports of the source handlers) ──────────────────────────────────

  void _setEnabled(bool enabled) {
    if (enabled && widget.state.ranges.isEmpty) {
      widget.onChanged(
        BeuiDayAvailability(
          enabled: true,
          ranges: [BeuiTimeRange(id: _nextId(), start: '09:00', end: '17:00')],
        ),
      );
    } else {
      widget.onChanged(widget.state.copyWith(enabled: enabled));
    }
  }

  void _updateRange(String id, {String? start, String? end}) {
    widget.onChanged(
      widget.state.copyWith(
        ranges: [
          for (final r in widget.state.ranges)
            if (r.id == id) r.copyWith(start: start, end: end) else r,
        ],
      ),
    );
  }

  void _addRange() {
    final ranges = widget.state.ranges;
    final start = ranges.isNotEmpty
        ? (toMinutes(ranges.last.end) + 60).clamp(0, 24 * 60 - 60)
        : 540;
    widget.onChanged(
      BeuiDayAvailability(
        enabled: true,
        ranges: [
          ...ranges,
          BeuiTimeRange(
            id: _nextId(),
            start: toValue(start),
            end: toValue(start + 60),
          ),
        ],
      ),
    );
  }

  void _removeRange(String id) {
    final ranges = widget.state.ranges.where((r) => r.id != id).toList();
    // Removing the last slot marks the day unavailable (source).
    widget.onChanged(
      BeuiDayAvailability(enabled: ranges.isNotEmpty, ranges: ranges),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BeuiTooltip(
          content: const Text('Add time'),
          child: SchedulerIconButton(
            label: 'Add time range to ${widget.day.label}',
            onPressed: _addRange,
            icon: const Icon(LucideIcons.plus),
          ),
        ),
        const SizedBox(width: 4),
        CopyMenu(fromLabel: widget.day.label, onApply: widget.onCopy),
      ],
    );

    Widget buildToggle({required bool flexLabel}) {
      final label = Text(
        widget.day.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.foreground,
        ),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 0.9,
            child: BeuiSwitch(
              value: widget.state.enabled,
              onChanged: _setEnabled,
            ),
          ),
          const SizedBox(width: 10),
          if (flexLabel) Flexible(child: label) else label,
        ],
      );
    }

    final ranges = _buildRanges(colors, reduce);
    final wide = MediaQuery.sizeOf(context).width >= _smBreakpoint;

    if (wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 144,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: buildToggle(flexLabel: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: ranges),
            const SizedBox(width: 16),
            Padding(padding: const EdgeInsets.only(top: 2), child: actions),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [buildToggle(flexLabel: false), actions],
          ),
          const SizedBox(height: 12),
          ranges,
        ],
      ),
    );
  }

  Widget _buildRanges(BeuiColors colors, bool reduce) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, slot) in _slots.indexed)
          _PresenceSlot(
            key: ValueKey(slot.key),
            exiting: slot.exiting,
            reduce: reduce,
            // Source column is `flex flex-col gap-2`: 8px *between* slots, with
            // no trailing gap after the last one.
            //
            // A slot that follows an *exiting* one carries no gap: the source's
            // `AnimatePresence mode="popLayout"` pulls a leaving slot out of
            // flow, so it never spaces the slot that replaces it. Keeping the
            // gap here instead made the column bulge while both were mounted
            // and then jump 8px the frame the leaver unmounted.
            gapBefore: i == 0 || _slots[i - 1].exiting ? 0 : 8,
            // Ranges enter from y -6 with a 4px blur; the unavailable line from
            // y -4 with no blur (source initial/exit specs).
            enterY: slot.range != null ? -6 : -4,
            exitY: -4,
            blurPx: slot.range != null ? 4 : 0,
            onExited: () => _onExited(slot),
            child: slot.range != null
                ? _RangeContent(
                    range: slot.range!,
                    options: widget.options,
                    colors: colors,
                    onStart: (v) => _updateRange(slot.range!.id, start: v),
                    onEnd: (v) => _updateRange(slot.range!.id, end: v),
                    onRemove: () => _removeRange(slot.range!.id),
                  )
                : _UnavailableContent(colors: colors),
          ),
      ],
    );
  }
}

/// A single range's editing row: `start – end` selects plus a remove button.
class _RangeContent extends StatelessWidget {
  const _RangeContent({
    required this.range,
    required this.options,
    required this.colors,
    required this.onStart,
    required this.onEnd,
    required this.onRemove,
  });

  final BeuiTimeRange range;
  final List<BeuiTimeOption> options;
  final BeuiColors colors;
  final ValueChanged<String> onStart;
  final ValueChanged<String> onEnd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // Each field is `min-w-0 flex-1 sm:max-w-[132px]`: it grows into its flex
    // share but stops at 132px, so a wide row keeps trailing slack rather than
    // stretching the fields (which is why the remove button does not sit flush
    // against the actions column).
    Widget field(Widget child) => Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );

    return Row(
      children: [
        field(
          TimeSelect(
            key: ValueKey('${range.id}-start'),
            value: range.start,
            options: options,
            onChanged: onStart,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('–', style: TextStyle(color: colors.mutedForeground)),
        ),
        field(
          TimeSelect(
            key: ValueKey('${range.id}-end'),
            value: range.end,
            options: options,
            onChanged: onEnd,
          ),
        ),
        const SizedBox(width: 8),
        BeuiTooltip(
          content: const Text('Remove'),
          child: SchedulerIconButton(
            label: 'Remove time range',
            onPressed: onRemove,
            icon: const Icon(LucideIcons.x),
          ),
        ),
      ],
    );
  }
}

/// The "Unavailable" line shown when a day is off.
class _UnavailableContent extends StatelessWidget {
  const _UnavailableContent({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // `py-1 sm:py-2` — 8px at the desktop breakpoint this port renders.
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Unavailable',
        style: TextStyle(
          fontSize: 14, // text-sm
          height: 20 / 14, // …/20
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

/// The presence wrapper — the same enter/exit/height-reflow contract as the
/// toast stack's `_ToastItem`, applied to a scheduler slot. Enter runs `0 → 1`
/// on `SPRING_LAYOUT`; exit runs `1 → 0` on the same spring and unmounts on
/// completion. [gapBefore] is included in the collapsing area so the spacing
/// reflows with the slot.
class _PresenceSlot extends StatelessWidget {
  const _PresenceSlot({
    required this.exiting,
    required this.reduce,
    required this.enterY,
    required this.exitY,
    required this.blurPx,
    required this.gapBefore,
    required this.onExited,
    required this.child,
    super.key,
  });

  final bool exiting;
  final bool reduce;
  final double enterY;
  final double exitY;
  final double blurPx;
  final double gapBefore;
  final VoidCallback onExited;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: exiting ? 0.0 : 1.0,
      from: 0.0,
      motion: beuiSpringLayout,
      onAnimationStatusChanged: (status) {
        if (exiting &&
            (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed)) {
          onExited();
        }
      },
      builder: (context, t, inner) {
        final opacity = t.clamp(0.0, 1.0);
        Widget body = inner!;
        if (!reduce) {
          final y = (exiting ? exitY : enterY) * (1 - t);
          final sigma = (blurPx / 2) * (1 - opacity); // blur(px) → σ = px/2
          if (sigma > 0.05) {
            body = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: body,
            );
          }
          body = Transform.translate(offset: Offset(0, y), child: body);
        }
        body = Opacity(opacity: opacity, child: body);
        // Height reflow: the slot's occupied height rides the same progress, so
        // siblings glide as slots enter/leave (source popLayout + layout).
        final heightFactor = reduce ? 1.0 : opacity;
        return ClipRect(
          child: Align(
            // `topStart`, not `topCenter`: the slot content is left-aligned in
            // the ranges column (the "Unavailable" line sits at the same left
            // edge as the start-time select).
            alignment: AlignmentDirectional.topStart,
            heightFactor: heightFactor,
            child: Padding(
              padding: EdgeInsets.only(top: gapBefore),
              child: body,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
