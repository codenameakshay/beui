import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for stacked composition.
Widget compositionChartDemo(BuildContext context) =>
    const _CompositionChartDemo();

class _CompositionChartDemo extends StatelessWidget {
  const _CompositionChartDemo();

  @override
  Widget build(BuildContext context) {
    final periods = List.generate(36, (index) {
      final date = DateTime.utc(2026, 8, index + 1);
      return '${_month(date.month)} ${date.day}';
    });
    const definitions = <(String, String, String, double, double)>[
      ('organic', 'Organic search', '#2563eb', 46, -0.45),
      ('direct', 'Direct', '#38bdf8', 24, 0.12),
      ('referral', 'Referrals', '#0d9488', 10, 0.32),
      ('social', 'Social', '#fbbf24', 12, 0.06),
      ('email', 'Email', '#a78bfa', 5, 0.09),
      ('other', 'Other', '#a1a1aa', 3, 0.02),
    ];
    final series = [
      for (var i = 0; i < definitions.length; i++)
        BeuiCompositionSeries(
          id: definitions[i].$1,
          name: definitions[i].$2,
          color: definitions[i].$3,
          values: [
            for (var day = 0; day < periods.length; day++)
              ((definitions[i].$4 +
                          day * definitions[i].$5 +
                          math.sin(day * 1.7 + i * 2) *
                              (definitions[i].$4 / 3 < 5
                                  ? definitions[i].$4 / 3
                                  : 5)) *
                      120)
                  .round(),
          ],
        ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiCompositionChart(
              series: series,
              periods: periods,
              view: BeuiCompositionView.bar,
              label: 'Illustrative acquisition channel shares',
              formatValue: (value) => '${value.round()} visits',
            ),
            const SizedBox(height: 20),
            BeuiCompositionChart(
              series: series,
              periods: periods,
              view: BeuiCompositionView.area,
              label: 'Illustrative acquisition channel shares',
              formatValue: (value) => '${value.round()} visits',
            ),
          ],
        ),
      ),
    );
  }
}

String _month(int month) => const [
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
][month - 1];
