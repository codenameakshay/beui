import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Heat-calendar preview matching the source registry sample.
Widget heatCalendarDemo(BuildContext context) => const _HeatCalendarDemo();

class _HeatCalendarDemo extends StatelessWidget {
  const _HeatCalendarDemo();

  double _level(int week, int day) {
    final s = math.sin(week * 12.9898 + day * 78.233) * 43758.5453;
    final random = s - s.floorToDouble();
    return day >= 5 ? math.max(0, random - 0.55) * 1.4 : random;
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: BeuiHeatCalendar(
        unit: 'commits',
        weeks: 16,
        maxCount: 14,
        values: [
          for (var week = 0; week < 16; week++)
            [for (var day = 0; day < 7; day++) _level(week, day)],
        ],
      ),
    ),
  );
}
