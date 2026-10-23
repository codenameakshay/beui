import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for [BeuiWheelPicker] — a 1:1 port of the source
/// `wheel-picker.preview`: three iOS-style wheels (month / day / year) forming a
/// date-of-birth picker, with a live "Born …" readout above. The day wheel
/// clamps to the number of days in the selected month/year, exactly like the
/// source preview.
Widget wheelPickerDemo(BuildContext context) => const _WheelPickerDemo();

const _months = <String>[
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
];

int _daysIn(int monthIndex, int year) => DateTime(year, monthIndex + 2, 0).day;

class _WheelPickerDemo extends StatefulWidget {
  const _WheelPickerDemo();

  @override
  State<_WheelPickerDemo> createState() => _WheelPickerDemoState();
}

class _WheelPickerDemoState extends State<_WheelPickerDemo> {
  String _month = 'June';
  String _year = '2004';
  String _day = '9';

  List<BeuiWheelPickerOption> _opts(Iterable<String> values) =>
      values.map(BeuiWheelPickerOption.text).toList();

  // A short month or a non-leap February can strand the day past the end —
  // pull it back to the last valid day (mirrors the source effect).
  void _clampDay() {
    final dayCount = _daysIn(_months.indexOf(_month), int.parse(_year));
    if (int.parse(_day) > dayCount) _day = '$dayCount';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    final monthIndex = _months.indexOf(_month);
    final year = int.parse(_year);
    final dayCount = _daysIn(monthIndex, year);
    final days = List<String>.generate(dayCount, (i) => '${i + 1}');
    final years = List<String>.generate(60, (i) => '${1980 + i}');

    const transparentStyle = BeuiWheelPickerStyle(
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 14, color: colors.mutedForeground),
            children: [
              const TextSpan(text: 'Born '),
              TextSpan(
                text: '$_month $_day, $_year',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4, // gap-1
            children: [
              BeuiWheelPicker(
                options: _opts(_months),
                value: _month,
                visibleCount: 7,
                itemHeight: 42,
                semanticLabel: 'Month',
                style: transparentStyle.copyWith(width: 128),
                onChanged: (v) => setState(() {
                  _month = v;
                  _clampDay();
                }),
              ),
              BeuiWheelPicker(
                options: _opts(days),
                value: _day,
                visibleCount: 7,
                itemHeight: 42,
                semanticLabel: 'Day',
                style: transparentStyle.copyWith(width: 56),
                onChanged: (v) => setState(() => _day = v),
              ),
              BeuiWheelPicker(
                options: _opts(years),
                value: _year,
                visibleCount: 7,
                itemHeight: 42,
                semanticLabel: 'Year',
                style: transparentStyle.copyWith(width: 80),
                onChanged: (v) => setState(() {
                  _year = v;
                  _clampDay();
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
