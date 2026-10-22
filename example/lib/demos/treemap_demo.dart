import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTreemap] — the source
/// `TreemapPreview` portfolio allocation by quarter.
Widget treemapDemo(BuildContext context) => const _TreemapDemo();

class _Group {
  const _Group({
    required this.id,
    required this.label,
    required this.color,
    required this.companies,
  });
  final String id;
  final String label;
  final String color;
  final List<String> companies;
}

const _groups = [
  _Group(
    id: 'technology',
    label: 'Technology',
    color: '#3454b5',
    companies: ['AAPL', 'MSFT', 'NVDA'],
  ),
  _Group(
    id: 'healthcare',
    label: 'Healthcare',
    color: '#087e6c',
    companies: ['LLY', 'UNH', 'JNJ'],
  ),
  _Group(
    id: 'finance',
    label: 'Finance',
    color: '#7c3db5',
    companies: ['JPM', 'V', 'BAC'],
  ),
  _Group(
    id: 'energy',
    label: 'Energy',
    color: '#a35318',
    companies: ['XOM', 'CVX', 'SHEL'],
  ),
];

const _quarters = <String, List<int>>{
  'q1': [210, 190, 130, 128, 85, 45, 80, 95, 30, 74, 62, 44],
  'q2': [170, 220, 175, 108, 50, 60, 90, 75, 56, 68, 69, 34],
  'q3': [260, 205, 155, 100, 95, 46, 140, 150, 0, 40, 50, 25],
};

List<BeuiTreemapNode> _dataFor(String quarter) {
  final values = _quarters[quarter]!;
  return [
    for (var i = 0; i < _groups.length; i++)
      BeuiTreemapNode.group(
        id: _groups[i].id,
        label: _groups[i].label,
        color: _groups[i].color,
        children: [
          for (var j = 0; j < _groups[i].companies.length; j++)
            BeuiTreemapNode.leaf(
              id: _groups[i].companies[j],
              label: _groups[i].companies[j],
              value: values[i * 3 + j] * 1000,
            ),
        ],
      ),
  ];
}

String _formatValue(double value) {
  final abs = value.abs();
  if (abs >= 1e6) return '\$${(value / 1e6).toStringAsFixed(1)}M';
  if (abs >= 1e3) return '\$${(value / 1e3).toStringAsFixed(1)}K';
  return '\$${value.round()}';
}

class _TreemapDemo extends StatefulWidget {
  const _TreemapDemo();

  @override
  State<_TreemapDemo> createState() => _TreemapDemoState();
}

class _TreemapDemoState extends State<_TreemapDemo> {
  String _quarter = 'q1';

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portfolio allocation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Demo data',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BeuiTabs<String>(
                    value: _quarter,
                    onChanged: (next) => setState(() => _quarter = next),
                    variant: BeuiTabsVariant.segment,
                    triggerPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    tabs: const [
                      BeuiTab(value: 'q1', label: Text('Q1')),
                      BeuiTab(value: 'q2', label: Text('Q2')),
                      BeuiTab(value: 'q3', label: Text('Q3')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              BeuiTreemap(
                data: _dataFor(_quarter),
                label: 'Portfolio allocation',
                formatValue: _formatValue,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BeuiTreemapPlot(height: 320),
                    SizedBox(height: 16),
                    BeuiTreemapTooltip(),
                    SizedBox(height: 12),
                    BeuiTreemapLegend(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
