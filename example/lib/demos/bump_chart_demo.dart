import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Preview for the bump chart.
Widget bumpChartDemo(BuildContext context) => const _BumpChartDemo();

class _BumpChartDemo extends StatelessWidget {
  const _BumpChartDemo();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: BeuiBumpChart(
          periods: ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
          label: 'Illustrative product rankings, April to September',
          series: [
            BeuiBumpSeries(
              id: 'studio',
              name: 'Studio',
              ranks: [4, 3, 2, 3, 2, 1],
              color: '#8b5cf6',
            ),
            BeuiBumpSeries(
              id: 'canvas',
              name: 'Canvas',
              ranks: [1, 1, 3, 2, 1, 2],
              color: '#0d9488',
            ),
            BeuiBumpSeries(
              id: 'layers',
              name: 'Layers',
              ranks: [3, 2, 1, 1, 3, 3],
              color: '#f59e0b',
            ),
            BeuiBumpSeries(
              id: 'orbit',
              name: 'Orbit',
              ranks: [2, 4, 5, 4, 5, 4],
              color: '#3b82f6',
            ),
            BeuiBumpSeries(
              id: 'frame',
              name: 'Frame',
              ranks: [5, 5, 4, 5, 4, 5],
              color: '#f43f5e',
            ),
          ],
        ),
      ),
    ),
  );
}
