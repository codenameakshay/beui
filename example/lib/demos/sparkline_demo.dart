import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Source-preview data and controls for the Sparkline gallery route.
Widget sparklineDemo(BuildContext context) => const _SparklineDemo();

List<double> _walk(
  int seed,
  int length,
  double start,
  double drift,
  double noise,
) {
  var state = seed;
  var value = start;
  return List<double>.generate(length, (_) {
    state = (state * 16807) % 2147483647;
    value = math
        .max(0, value + drift + (state / 2147483647 - .5) * noise)
        .toDouble();
    return (value * 100).roundToDouble() / 100;
  });
}

final _days = List<String>.generate(60, (index) {
  final date = DateTime.utc(2026, 9, 1 + index);
  const months = [
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
  return '${months[date.month - 1]} ${date.day}';
});
final _revenue = _walk(14, 60, 42, .6, 7);
final _users = _walk(49, 60, 1800, 4, 160);
final _errors = _walk(49, 60, 2.4, -.03, .5);

class _SparklineDemo extends StatefulWidget {
  const _SparklineDemo();

  @override
  State<_SparklineDemo> createState() => _SparklineDemoState();
}

class _SparklineDemoState extends State<_SparklineDemo> {
  static const _window = 30;
  int _offset = 0;

  List<T> _slice<T>(List<T> values) =>
      values.sublist(_offset, _offset + _window);

  @override
  Widget build(BuildContext context) {
    final days = _slice(_days);
    final revenue = _slice(_revenue);
    final users = _slice(_users);
    final errors = _slice(_errors);
    final cards = <_SparklineCardData>[
      _SparklineCardData(
        title: 'Revenue',
        value: _money(revenue.last),
        data: revenue,
        color: '#2563eb',
        format: _money,
      ),
      _SparklineCardData(
        title: 'Active users',
        value: _integer(users.last),
        data: users,
        color: '#0d9488',
        format: _integer,
      ),
      _SparklineCardData(
        title: 'Error rate',
        value: '${errors.last.toStringAsFixed(2)}%',
        data: errors,
        color: '#e11d48',
        format: (value) => '${value.toStringAsFixed(2)}%',
        invertDelta: true,
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Last 30 days, demo data',
                    style: TextStyle(
                      color: BeuiColors.resolve(context).mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                ),
                BeuiButton(
                  variant: BeuiButtonVariant.ghost,
                  size: BeuiButtonSize.sm,
                  onPressed: _offset >= _days.length - _window
                      ? null
                      : () =>
                            setState(() => _offset = math.min(30, _offset + 1)),
                  child: const Text('Add sample'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final children = [
                  for (final card in cards) _buildStatCard(context, card, days),
                ];
                return constraints.maxWidth < 640
                    ? Column(
                        children: [
                          for (var index = 0; index < children.length; index++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == children.length - 1 ? 0 : 12,
                              ),
                              child: children[index],
                            ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var index = 0;
                            index < children.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 12),
                            Expanded(child: children[index]),
                          ],
                        ],
                      );
              },
            ),
            const SizedBox(height: 24),
            _sourceCard(
              context,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interactive: hover, drag or use the arrow keys',
                    style: TextStyle(
                      color: BeuiColors.resolve(context).mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  BeuiSparkline(
                    data: users,
                    labels: days,
                    label: 'Active users, last 30 days',
                    color: '#0d9488',
                    height: 48,
                    strokeWidth: 2,
                    interactive: true,
                    formatValue: (value) => _integer(value.toDouble()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    _SparklineCardData card,
    List<String> days,
  ) => _sourceCard(
    context,
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                card.title,
                style: TextStyle(
                  color: BeuiColors.resolve(context).mutedForeground,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              card.value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BeuiSparkline(
          data: card.data,
          labels: days,
          label: '${card.title}, last 30 days',
          variant: BeuiSparklineVariant.area,
          color: card.color,
          height: 40,
          showDelta: true,
          invertDelta: card.invertDelta,
          formatValue: card.format,
        ),
      ],
    ),
  );

  Widget _sourceCard(
    BuildContext context, {
    required EdgeInsets padding,
    required Widget child,
  }) {
    final colors = BeuiColors.resolve(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _SparklineCardData {
  const _SparklineCardData({
    required this.title,
    required this.value,
    required this.data,
    required this.color,
    required this.format,
    this.invertDelta = false,
  });

  final String title;
  final String value;
  final List<double> data;
  final String color;
  final String Function(num) format;
  final bool invertDelta;
}

String _money(num value) => '\$${value.toStringAsFixed(1)}K';

String _integer(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
