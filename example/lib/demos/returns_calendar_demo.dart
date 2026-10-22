import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Returns-calendar preview matching the source registry sample.
Widget returnsCalendarDemo(BuildContext context) =>
    const _ReturnsCalendarDemo();

class _ReturnsCalendarDemo extends StatelessWidget {
  const _ReturnsCalendarDemo();

  static const _years = [2021, 2022, 2023, 2024, 2025];

  List<List<double>> _sample() {
    var seed = 2021;
    double random() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    return [
      for (var yi = 0; yi < _years.length; yi++)
        [
          for (var month = 0; month < 12; month++)
            (((yi == 1 ? -1.6 : 0.9) + (random() - 0.5) * 12) * 10).round() /
                10,
        ],
    ];
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: BeuiReturnsCalendar(years: _years, returns: _sample()),
    ),
  );
}
