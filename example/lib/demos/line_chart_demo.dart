import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Source-preview data for the line-chart gallery route.
Widget lineChartDemo(BuildContext context) => const _LineChartDemo();

const _months = [
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
];

List<BeuiLineChartSeries> _makeSeries(int seed) {
  var state = seed;
  double random() {
    state = (state * 16807) % 2147483647;
    return state / 2147483647;
  }

  List<num> walk(double start, double drift) {
    var value = start;
    return [
      for (var i = 0; i < _months.length; i++)
        (() {
          value = (value + drift + (random() - .45) * 9).clamp(
            4,
            double.infinity,
          );
          return (value * 10).round() / 10;
        })(),
    ];
  }

  return [
    BeuiLineChartSeries(
      id: 'this-year',
      name: 'This year',
      color: '#2563eb',
      values: walk(38, 2.4),
    ),
    BeuiLineChartSeries(
      id: 'last-year',
      name: 'Last year',
      color: '#a1a1aa',
      values: walk(32, 1.2),
    ),
    BeuiLineChartSeries(
      id: 'target',
      name: 'Target',
      color: '#0d9488',
      values: [for (var i = 0; i < _months.length; i++) 36 + i * 2.5],
    ),
  ];
}

class _LineChartDemo extends StatefulWidget {
  const _LineChartDemo();

  @override
  State<_LineChartDemo> createState() => _LineChartDemoState();
}

class _LineChartDemoState extends State<_LineChartDemo> {
  BeuiLineChartVariant _variant = BeuiLineChartVariant.area;
  int _seed = 7;
  bool _loading = false;
  Timer? _reload;

  void _newData() {
    setState(() => _seed = (_seed * 48271) % 2147483647);
  }

  void _reloadData() {
    if (_loading) return;
    setState(() => _loading = true);
    _reload?.cancel();
    _reload = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _seed = (_seed * 48271) % 2147483647;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _reload?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 768),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Monthly revenue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Demo data, in thousands of dollars',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  BeuiTabs<BeuiLineChartVariant>(
                    value: _variant,
                    onChanged: (value) => setState(() => _variant = value),
                    variant: BeuiTabsVariant.pill,
                    tabs: const [
                      BeuiTab(
                        value: BeuiLineChartVariant.line,
                        label: Text('Line'),
                      ),
                      BeuiTab(
                        value: BeuiLineChartVariant.area,
                        label: Text('Area'),
                      ),
                    ],
                  ),
                  BeuiButton(
                    variant: BeuiButtonVariant.ghost,
                    size: BeuiButtonSize.sm,
                    onPressed: _loading ? null : _newData,
                    child: const Text('New data'),
                  ),
                  BeuiButton(
                    variant: BeuiButtonVariant.ghost,
                    size: BeuiButtonSize.sm,
                    onPressed: _loading ? null : _reloadData,
                    child: const Text('Reload'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          BeuiLineChart(
            series: _makeSeries(_seed),
            categories: _months,
            variant: _variant,
            status: _loading
                ? BeuiLineChartStatus.loading
                : BeuiLineChartStatus.ready,
            label: 'Illustrative monthly revenue',
            formatValue: (value) => '\$${value.toStringAsFixed(1)}K',
            formatTick: (value) =>
                value == 0 ? r'$0' : '\$${value.toStringAsFixed(0)}K',
          ),
        ],
      ),
    ),
  );
}
