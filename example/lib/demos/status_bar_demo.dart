import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for status history.
Widget statusBarDemo(BuildContext context) => const _StatusBarDemo();

class _StatusBarDemo extends StatelessWidget {
  const _StatusBarDemo();

  @override
  Widget build(BuildContext context) {
    final history = List.generate(48, (i) {
      final date = DateTime.utc(2026, 8, 21 + i);
      final label = '${_month(date.month)} ${date.day}';
      return BeuiStatusBarDatum(
        id: date.toIso8601String().substring(0, 10),
        label: label,
        status: i == 8 ? 'degraded' : 'operational',
        description: i == 8
            ? 'Elevated response times for 12 minutes.'
            : 'All checks passed.',
      );
    });
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: BeuiStatusBar(
          data: history,
          statuses: STATUS_BAR_STATUSES.take(3).toList(),
          label: 'API status',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('API', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              BeuiStatusBarPlot(),
              BeuiStatusBarTooltip(),
              SizedBox(height: 8),
              BeuiStatusBarLegend(),
            ],
          ),
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
