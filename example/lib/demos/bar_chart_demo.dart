import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

Widget barChartDemo(BuildContext context) => const BarChartDemo();

const _regions = [
  'North America',
  'Europe',
  'Asia Pacific',
  'Latin America',
  'Middle East',
  'Africa',
];

List<BeuiBarChartSeries> _series(int seed) {
  var state = seed;
  double random() {
    state = (state * 16807) % 2147483647;
    return state / 2147483647;
  }

  const scale = [1, .85, .7, .4, .3, .2];
  List<num> row(int base) => [
    for (final factor in scale) (base * factor * (.55 + random())).round(),
  ];
  return [
    BeuiBarChartSeries(
      id: 'subscriptions',
      name: 'Subscriptions',
      color: '#2563eb',
      values: row(120),
    ),
    BeuiBarChartSeries(
      id: 'services',
      name: 'Services',
      color: '#38bdf8',
      values: row(70),
    ),
    BeuiBarChartSeries(
      id: 'marketplace',
      name: 'Marketplace',
      color: '#0d9488',
      values: row(45),
    ),
  ];
}

/// Source preview controls and the deterministic seed-11 chart data.
class BarChartDemo extends StatefulWidget {
  const BarChartDemo({super.key});

  @override
  State<BarChartDemo> createState() => _BarChartDemoState();
}

class _BarChartDemoState extends State<BarChartDemo> {
  var _layout = BeuiBarChartLayout.grouped;
  var _orientation = BeuiBarChartOrientation.vertical;
  var _sorted = false;
  var _seed = 11;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 768),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Revenue by region',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Demo data, in thousands of dollars',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SegmentedButton<BeuiBarChartLayout>(
                showSelectedIcon: false,
                segments: [
                  for (final value in BeuiBarChartLayout.values)
                    ButtonSegment(value: value, label: Text(value.name)),
                ],
                selected: {_layout},
                onSelectionChanged: (values) =>
                    setState(() => _layout = values.first),
              ),
              SegmentedButton<BeuiBarChartOrientation>(
                showSelectedIcon: false,
                segments: [
                  for (final value in BeuiBarChartOrientation.values)
                    ButtonSegment(value: value, label: Text(value.name)),
                ],
                selected: {_orientation},
                onSelectionChanged: (values) =>
                    setState(() => _orientation = values.first),
              ),
              FilterChip(
                label: const Text('Sort by total'),
                selected: _sorted,
                onSelected: (value) => setState(() => _sorted = value),
              ),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _seed = (_seed * 48271) % 2147483647),
                child: const Text('New data'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          BeuiBarChart(
            key: ValueKey(_orientation),
            series: _series(_seed),
            categories: _regions,
            layout: _layout,
            orientation: _orientation,
            sort: _sorted ? BeuiBarChartSort.descending : BeuiBarChartSort.none,
            label: 'Illustrative revenue by region',
            formatValue: (value) => '\$${value.toStringAsFixed(0)}K',
            formatTick: (value) =>
                value == 0 ? '\$0' : '\$${value.toStringAsFixed(0)}K',
          ),
        ],
      ),
    ),
  );
}

/// Caller-data composition matching the source's stacked, descending example.
class BarChartUsageDemo extends StatelessWidget {
  const BarChartUsageDemo({
    super.key,
    required this.series,
    required this.categories,
  });
  final List<BeuiBarChartSeries> series;
  final List<String> categories;

  @override
  Widget build(BuildContext context) => BeuiBarChart(
    series: series,
    categories: categories,
    layout: BeuiBarChartLayout.stacked,
    sort: BeuiBarChartSort.descending,
    label: 'Revenue by region',
    formatValue: (value) => '\$${value.toStringAsFixed(0)}',
    child: const Column(
      children: [
        BeuiBarChartPlot(),
        SizedBox(height: 12),
        BeuiBarChartTooltip(),
        SizedBox(height: 12),
        BeuiBarChartLegend(),
      ],
    ),
  );
}
