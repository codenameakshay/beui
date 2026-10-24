import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Source income statement preview, with the exact illustrative Q2/Q3 figures.
Widget sankeyChartDemo(BuildContext context) => const SankeyChartDemo();

/// Interactive source preview.
class SankeyChartDemo extends StatefulWidget {
  /// Creates the source preview.
  const SankeyChartDemo({super.key});
  @override
  State<SankeyChartDemo> createState() => _SankeyChartDemoState();
}

/// Source nodes, in their original order.
const sankeyDemoNodes = <BeuiSankeyNode>[
  BeuiSankeyNode(
    id: 'subscriptions',
    label: 'Subscriptions',
    color: Color(0xff2563eb),
  ),
  BeuiSankeyNode(id: 'services', label: 'Services', color: Color(0xff38bdf8)),
  BeuiSankeyNode(
    id: 'marketplace',
    label: 'Marketplace',
    color: Color(0xff6366f1),
  ),
  BeuiSankeyNode(id: 'revenue', label: 'Revenue', color: Color(0xff64748b)),
  BeuiSankeyNode(
    id: 'cost',
    label: 'Cost of revenue',
    color: Color(0xffe11d48),
  ),
  BeuiSankeyNode(id: 'gross', label: 'Gross profit', color: Color(0xff0d9488)),
  BeuiSankeyNode(id: 'rnd', label: 'R&D', color: Color(0xfff59e0b)),
  BeuiSankeyNode(
    id: 'sales',
    label: 'Sales & marketing',
    color: Color(0xfffb923c),
  ),
  BeuiSankeyNode(id: 'admin', label: 'G&A', color: Color(0xfffbbf24)),
  BeuiSankeyNode(
    id: 'operating',
    label: 'Operating profit',
    color: Color(0xff16a34a),
  ),
];

/// Exact source quarter weights, including derived gross and operating profit.
List<BeuiSankeyLink> sankeyDemoLinks(String quarter) {
  final v = quarter == 'q2'
      ? [62.0, 18.0, 10.0, 34.0, 20.0, 16.0, 7.0]
      : [70.0, 17.0, 14.0, 36.0, 22.0, 17.0, 7.0];
  final gross = v[0] + v[1] + v[2] - v[3];
  return [
    BeuiSankeyLink(source: 'subscriptions', target: 'revenue', value: v[0]),
    BeuiSankeyLink(source: 'services', target: 'revenue', value: v[1]),
    BeuiSankeyLink(source: 'marketplace', target: 'revenue', value: v[2]),
    BeuiSankeyLink(source: 'revenue', target: 'cost', value: v[3]),
    BeuiSankeyLink(source: 'revenue', target: 'gross', value: gross),
    BeuiSankeyLink(source: 'gross', target: 'rnd', value: v[4]),
    BeuiSankeyLink(source: 'gross', target: 'sales', value: v[5]),
    BeuiSankeyLink(source: 'gross', target: 'admin', value: v[6]),
    BeuiSankeyLink(
      source: 'gross',
      target: 'operating',
      value: gross - v[4] - v[5] - v[6],
    ),
  ];
}

class _SankeyChartDemoState extends State<SankeyChartDemo> {
  String quarter = 'q3';
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 768),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Theme(
              data: Theme.of(context).copyWith(
                extensions: [
                  ...Theme.of(
                    context,
                  ).extensions.values.where((value) => value is! BeuiColors),
                  BeuiColors.resolve(context).copyWith(
                    primary: const Color(0xff0285f7),
                    primaryForeground: const Color(0xffffffff),
                  ),
                ],
              ),
              child: BeuiTabs<String>(
                value: quarter,
                onChanged: (q) => setState(() => quarter = q),
                variant: BeuiTabsVariant.segment,
                tabs: const [
                  BeuiTab(value: 'q2', label: Text('Q2')),
                  BeuiTab(value: 'q3', label: Text('Q3')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          BeuiSankeyChart(
            nodes: sankeyDemoNodes,
            links: sankeyDemoLinks(quarter),
            label: 'Income statement, ${quarter.toUpperCase()}',
            formatValue: (v) => '\$${beuiChartFormatNumber(v)}M',
          ),
        ],
      ),
    ),
  );
}
