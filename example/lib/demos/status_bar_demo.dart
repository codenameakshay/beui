import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for status history.
Widget statusBarDemo(BuildContext context) => const _StatusBarDemo();

class _StatusBarDemo extends StatefulWidget {
  const _StatusBarDemo();

  @override
  State<_StatusBarDemo> createState() => _StatusBarDemoState();
}

class _StatusBarDemoState extends State<_StatusBarDemo> {
  bool _incident = false;
  int _replay = 0;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '48 days of status',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                BeuiButton(
                  variant: BeuiButtonVariant.ghost,
                  size: BeuiButtonSize.sm,
                  onPressed: () => setState(() => _replay++),
                  child: const Text('Replay'),
                ),
                BeuiButton(
                  variant: BeuiButtonVariant.ghost,
                  size: BeuiButtonSize.sm,
                  onPressed: () => setState(() => _incident = !_incident),
                  child: Text(
                    _incident ? 'Resolve incident' : 'Simulate incident',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            for (final website in [false, true]) ...[
              if (website) ...[
                const SizedBox(height: 24),
                Divider(color: BeuiColors.resolve(context).border),
                const SizedBox(height: 24),
              ],
              BeuiStatusBar(
                key: ValueKey('${website ? 'website' : 'api'}-$_replay'),
                data: [
                  for (var i = 0; i < history.length; i++)
                    BeuiStatusBarDatum(
                      id: history[i].id,
                      label: history[i].label,
                      status: website
                          ? 'operational'
                          : _incident && i >= 45
                          ? (i == 46 ? 'outage' : 'degraded')
                          : history[i].status,
                      description: website
                          ? 'All checks passed.'
                          : _incident && i >= 45
                          ? (i == 46
                                ? 'Requests failed for 4 minutes.'
                                : 'Elevated response times.')
                          : history[i].description,
                    ),
                ],
                statuses: STATUS_BAR_STATUSES.take(3).toList(),
                label: website ? 'Website status' : 'API status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          website ? 'Website' : 'API',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          !website && _incident ? 'Degraded' : 'Operational',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const BeuiStatusBarPlot(),
                    const BeuiStatusBarTooltip(),
                    if (website) ...[
                      const SizedBox(height: 8),
                      const BeuiStatusBarLegend(),
                    ],
                  ],
                ),
              ),
            ],
          ],
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
