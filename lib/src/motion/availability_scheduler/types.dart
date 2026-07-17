/// The schedule model for [BeuiAvailabilityScheduler] — a one-to-one port of the
/// source `availability-scheduler/types.ts`.
///
/// The types are deliberately value types with structural equality so a
/// controlled consumer can diff `onChanged` payloads and the widget can key
/// range slots by their stable [BeuiTimeRange.id].
library;

import 'package:flutter/foundation.dart';

/// A weekday key + its display label (source `DayKey` + the `WEEKDAYS` table,
/// collapsed into a single enum). Iteration order is Monday → Sunday.
enum BeuiDayKey {
  /// Monday.
  mon('Monday'),

  /// Tuesday.
  tue('Tuesday'),

  /// Wednesday.
  wed('Wednesday'),

  /// Thursday.
  thu('Thursday'),

  /// Friday.
  fri('Friday'),

  /// Saturday.
  sat('Saturday'),

  /// Sunday.
  sun('Sunday');

  const BeuiDayKey(this.label);

  /// The full weekday name shown in the row (source `WEEKDAYS[].label`).
  final String label;
}

/// A single availability window within a day (source `TimeRange`).
///
/// [start] and [end] are 24-hour `"HH:mm"` strings (the canonical value the
/// [BeuiTimeOption]s carry); render them as 12-hour labels with [label12].
@immutable
class BeuiTimeRange {
  /// Creates a time range. [id] is a stable identity used to key add/remove
  /// animations.
  const BeuiTimeRange({required this.id, required this.start, required this.end});

  /// Stable identity across list updates — drives the enter/exit animation of
  /// the range's row.
  final String id;

  /// Inclusive start, `"HH:mm"` (24-hour).
  final String start;

  /// Exclusive end, `"HH:mm"` (24-hour).
  final String end;

  /// Returns a copy with the given fields replaced.
  BeuiTimeRange copyWith({String? id, String? start, String? end}) =>
      BeuiTimeRange(
        id: id ?? this.id,
        start: start ?? this.start,
        end: end ?? this.end,
      );

  @override
  bool operator ==(Object other) =>
      other is BeuiTimeRange &&
      other.id == id &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(id, start, end);
}

/// One day's availability (source `DayAvailability`): whether the day is
/// [enabled] and its list of [ranges].
@immutable
class BeuiDayAvailability {
  /// Creates a day's availability.
  const BeuiDayAvailability({required this.enabled, required this.ranges});

  /// Whether the day is marked available.
  final bool enabled;

  /// The day's time windows (kept even while [enabled] is false, so a re-enable
  /// restores the previous hours — matching the source `defaultWeek` weekend).
  final List<BeuiTimeRange> ranges;

  /// Returns a copy with the given fields replaced.
  BeuiDayAvailability copyWith({bool? enabled, List<BeuiTimeRange>? ranges}) =>
      BeuiDayAvailability(
        enabled: enabled ?? this.enabled,
        ranges: ranges ?? this.ranges,
      );

  @override
  bool operator ==(Object other) =>
      other is BeuiDayAvailability &&
      other.enabled == enabled &&
      listEquals(other.ranges, ranges);

  @override
  int get hashCode => Object.hash(enabled, Object.hashAll(ranges));
}

/// A full week's availability, keyed by [BeuiDayKey] (source
/// `WeekAvailability = Record<DayKey, DayAvailability>`).
///
/// It is a plain [Map] so consumers can build/patch it directly; copy with
/// `Map.of(week)..[day] = next` when producing a new value in `onChanged`.
typedef BeuiWeekAvailability = Map<BeuiDayKey, BeuiDayAvailability>;

/// One selectable time in a [BeuiAvailabilityScheduler] dropdown — the 24-hour
/// [value] and its 12-hour display [label] (source `TimeOption`). Internal.
@immutable
class BeuiTimeOption {
  /// Creates a time option.
  const BeuiTimeOption({required this.value, required this.label});

  /// Canonical `"HH:mm"` (24-hour) value stored in the model.
  final String value;

  /// 12-hour display label, e.g. `9:00 AM`.
  final String label;
}

/// Minutes since midnight for a `"HH:mm"` value (source `toMinutes`).
int toMinutes(String v) {
  final parts = v.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// A `"HH:mm"` value for [mins] since midnight, clamped to `[0, 24*60-1]`
/// (source `toValue`).
String toValue(int mins) {
  final clamped = mins.clamp(0, 24 * 60 - 1);
  final h = clamped ~/ 60;
  final m = clamped % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// 12-hour display label for a `"HH:mm"` value, e.g. `"13:30"` → `"1:30 PM"`
/// (source `label12`).
String label12(String v) {
  final parts = v.split(':');
  final h = int.parse(parts[0]);
  final m = parts[1];
  final ap = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $ap';
}

/// Builds the selectable time options at [step]-minute intervals across a full
/// day (source `buildOptions`). Default step 30 → 48 options.
List<BeuiTimeOption> buildOptions(int step) {
  final out = <BeuiTimeOption>[];
  for (var m = 0; m < 24 * 60; m += step) {
    final value = toValue(m);
    out.add(BeuiTimeOption(value: value, label: label12(value)));
  }
  return out;
}

/// The default week: Mon–Fri available 9:00–17:00, weekend off (source
/// `defaultWeek`). Off days keep a hidden 9–5 range so toggling them on restores
/// those hours.
BeuiWeekAvailability beuiDefaultWeek() {
  BeuiDayAvailability workday(BeuiDayKey day) => BeuiDayAvailability(
    enabled: true,
    ranges: [BeuiTimeRange(id: '${day.name}-0', start: '09:00', end: '17:00')],
  );
  BeuiDayAvailability off(BeuiDayKey day) => BeuiDayAvailability(
    enabled: false,
    ranges: [BeuiTimeRange(id: '${day.name}-0', start: '09:00', end: '17:00')],
  );
  return <BeuiDayKey, BeuiDayAvailability>{
    BeuiDayKey.mon: workday(BeuiDayKey.mon),
    BeuiDayKey.tue: workday(BeuiDayKey.tue),
    BeuiDayKey.wed: workday(BeuiDayKey.wed),
    BeuiDayKey.thu: workday(BeuiDayKey.thu),
    BeuiDayKey.fri: workday(BeuiDayKey.fri),
    BeuiDayKey.sat: off(BeuiDayKey.sat),
    BeuiDayKey.sun: off(BeuiDayKey.sun),
  };
}
