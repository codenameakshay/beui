import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Preview for the bump chart.
Widget bumpChartDemo(BuildContext context) => const _BumpChartDemo();

class _BumpChartDemo extends StatefulWidget {
  const _BumpChartDemo();

  @override
  State<_BumpChartDemo> createState() => _BumpChartDemoState();
}

class _BumpChartDemoState extends State<_BumpChartDemo> {
  final _random = math.Random();
  List<List<int?>> _ranks = [
    [4, 3, 2, 3, 2, 1],
    [1, 1, 3, 2, 1, 2],
    [3, 2, 1, 1, 3, 3],
    [2, 4, 5, 4, 5, 4],
    [5, 5, 4, 5, 4, 5],
  ];

  void _shuffle() {
    final columns = List.generate(6, (_) => [1, 2, 3, 4, 5]..shuffle(_random));
    setState(
      () => _ranks = List.generate(
        5,
        (row) => List.generate(6, (column) => columns[column][row]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 752),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The leaderboard',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Five products. Six months. Every move.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: BeuiColors.resolve(context).mutedForeground,
                      ),
                    ),
                  ],
                ),
                BeuiButton(
                  variant: BeuiButtonVariant.ghost,
                  size: BeuiButtonSize.sm,
                  onPressed: _shuffle,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.shuffle, size: 14),
                      SizedBox(width: 8),
                      Text('Shuffle rankings'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BeuiBumpChart(
            periods: ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
            label: 'Illustrative product rankings, April to September',
            series: [
              BeuiBumpSeries(
                id: 'studio',
                name: 'Studio',
                ranks: _ranks[0],
                color: '#8b5cf6',
              ),
              BeuiBumpSeries(
                id: 'canvas',
                name: 'Canvas',
                ranks: _ranks[1],
                color: '#0d9488',
              ),
              BeuiBumpSeries(
                id: 'layers',
                name: 'Layers',
                ranks: _ranks[2],
                color: '#f59e0b',
              ),
              BeuiBumpSeries(
                id: 'orbit',
                name: 'Orbit',
                ranks: _ranks[3],
                color: '#3b82f6',
              ),
              BeuiBumpSeries(
                id: 'frame',
                name: 'Frame',
                ranks: _ranks[4],
                color: '#f43f5e',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Inspect a dot for details · Select to pin a product',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: BeuiColors.resolve(context).mutedForeground,
            ),
          ),
        ],
      ),
    ),
  );
}
