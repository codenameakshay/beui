import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the donut chart.
Widget donutChartDemo(BuildContext context) => const _DonutChartDemo();

class _DonutChartDemo extends StatelessWidget {
  const _DonutChartDemo();
  static const segments = [
    BeuiDonutSegment(id: 'team', label: 'Team', value: 42900, color: '#2563eb'),
    BeuiDonutSegment(
      id: 'business',
      label: 'Business',
      value: 31250,
      color: '#38bdf8',
    ),
    BeuiDonutSegment(
      id: 'enterprise',
      label: 'Enterprise',
      value: 22600,
      color: '#0d9488',
    ),
    BeuiDonutSegment(
      id: 'starter',
      label: 'Starter',
      value: 18400,
      color: '#fbbf24',
    ),
  ];
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: BeuiDonutChart(
        segments: segments,
        label: 'Monthly revenue by plan',
        formatValue: (v) => '\$${beuiChartFormatNumber(v)}',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  SizedBox(width: 200, child: BeuiDonutPlot()),
                  SizedBox(width: 16),
                  Expanded(child: BeuiDonutLegend()),
                ],
              ),
            ),
            SizedBox(height: 10),
            Text('Select a plan to filter'),
          ],
        ),
      ),
    ),
  );
}
