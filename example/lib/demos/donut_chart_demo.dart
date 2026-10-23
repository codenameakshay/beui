import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the donut chart.
Widget donutChartDemo(BuildContext context) => const _DonutChartDemo();

class _DonutChartDemo extends StatefulWidget {
  const _DonutChartDemo();

  @override
  State<_DonutChartDemo> createState() => _DonutChartDemoState();
}

class _DonutChartDemoState extends State<_DonutChartDemo> {
  String? _selected;
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
      constraints: const BoxConstraints(maxWidth: 576),
      child: BeuiDonutChart(
        segments: segments,
        label: 'Monthly revenue by plan',
        formatValue: (v) => '\$${beuiChartFormatNumber(v)}',
        selectedId: _selected,
        onSelect: (id) =>
            setState(() => _selected = _selected == id ? null : id),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = MediaQuery.sizeOf(context).width < 640;
                final size = narrow ? 256.0 : 240.0;
                final plot = SizedBox(
                  width: size,
                  height: size,
                  child: const BeuiDonutPlot(
                    child: BeuiDonutCenter(totalLabel: 'Monthly revenue'),
                  ),
                );
                return narrow
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          plot,
                          const SizedBox(height: 24),
                          const BeuiDonutLegend(),
                        ],
                      )
                    : Row(
                        children: [
                          plot,
                          const SizedBox(width: 24),
                          const Expanded(child: BeuiDonutLegend()),
                        ],
                      );
              },
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _selected == null
                    ? 'Select a plan to filter'
                    : 'Filtering by ${segments.firstWhere((s) => s.id == _selected).label}',
                style: TextStyle(
                  fontSize: 12,
                  color: BeuiColors.resolve(context).mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
