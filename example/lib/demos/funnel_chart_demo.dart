import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for the conversion funnel.
Widget funnelChartDemo(BuildContext context) => const _FunnelChartDemo();

class _FunnelChartDemo extends StatefulWidget {
  const _FunnelChartDemo();

  @override
  State<_FunnelChartDemo> createState() => _FunnelChartDemoState();
}

class _FunnelChartDemoState extends State<_FunnelChartDemo> {
  BeuiFunnelDirection _direction = BeuiFunnelDirection.vertical;
  int _cohort = 0;

  static const _labels = [
    'Visitors',
    'Signed up',
    'Activated',
    'Started trial',
    'Subscribed',
  ];
  static const _cohorts = [
    [24000, 15600, 10800, 7200, 4320],
    [28000, 18200, 13650, 9100, 6370],
    [22000, 13200, 7920, 4752, 2376],
  ];

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('From first visit to first payment')),
              TextButton(
                onPressed: () =>
                    setState(() => _cohort = (_cohort + 1) % _cohorts.length),
                child: const Text('Next cohort'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final direction in BeuiFunnelDirection.values)
                ChoiceChip(
                  label: Text(direction.name),
                  selected: _direction == direction,
                  onSelected: (_) => setState(() => _direction = direction),
                ),
            ],
          ),
          const SizedBox(height: 12),
          BeuiFunnelChart(
            direction: _direction,
            stages: [
              for (var i = 0; i < _labels.length; i++)
                BeuiFunnelStage(
                  id: _labels[i],
                  label: _labels[i],
                  value: _cohorts[_cohort][i],
                ),
            ],
          ),
          const Text(
            'Inspect a stage to see conversion and drop-off',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
