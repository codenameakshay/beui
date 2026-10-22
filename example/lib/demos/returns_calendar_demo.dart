import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Returns-calendar preview matching the source registry sample.
Widget returnsCalendarDemo(BuildContext context) =>
    const _ReturnsCalendarDemo();

class _ReturnsCalendarDemo extends StatelessWidget {
  const _ReturnsCalendarDemo();

  static const _years = [2021, 2022, 2023, 2024, 2025];

  /// Source preview field (JS ToInt32 LCG).
  static const _sample = [
    [1.1, 4.0, -4.2, 5.5, 6.9, 5.4, 5.2, -2.9, -2.3, -1.9, -3.9, 1.6],
    [3.4, -3.3, -4.5, -0.4, -3.4, -3.0, -1.4, -1.1, -7.0, 3.8, 0.3, 2.4],
    [4.9, 2.4, 0.7, -1.9, 0.0, 5.3, 6.2, 4.3, 4.6, 5.1, -2.6, -0.6],
    [-3.2, -2.2, -2.3, -2.3, 4.1, -2.2, 3.2, -3.3, -3.7, 4.0, -0.8, 3.5],
    [4.4, -0.8, 3.8, -1.8, -3.1, -2.3, -3.0, 4.6, -1.7, -0.7, -4.8, -2.8],
  ];

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: BeuiReturnsCalendar(years: _years, returns: _sample),
    ),
  );
}
