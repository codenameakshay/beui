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
      constraints: const BoxConstraints(maxWidth: 752),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'From first visit to first payment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Product conversion · Sample cohorts',
                      style: TextStyle(
                        fontSize: 12,
                        color: BeuiColors.resolve(context).mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              BeuiButton(
                variant: BeuiButtonVariant.ghost,
                size: BeuiButtonSize.sm,
                onPressed: () =>
                    setState(() => _cohort = (_cohort + 1) % _cohorts.length),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.refresh_cw, size: 14),
                    SizedBox(width: 8),
                    Text('Next cohort'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: 'Funnel direction',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: BeuiColors.resolve(
                    context,
                  ).muted.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final direction in BeuiFunnelDirection.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Semantics(
                          selected: _direction == direction,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _direction == direction
                                  ? BeuiColors.resolve(context).background
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: _direction == direction
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x0D000000),
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: BeuiButton(
                              variant: BeuiButtonVariant.ghost,
                              size: BeuiButtonSize.sm,
                              onPressed: () =>
                                  setState(() => _direction = direction),
                              child: Text(
                                direction == BeuiFunnelDirection.vertical
                                    ? 'Vertical'
                                    : 'Horizontal',
                                style: TextStyle(
                                  color: _direction == direction
                                      ? BeuiColors.resolve(context).foreground
                                      : BeuiColors.resolve(
                                          context,
                                        ).mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
          Text(
            'Inspect a stage to see conversion and drop-off',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: BeuiColors.resolve(context).mutedForeground,
            ),
          ),
        ],
      ),
    ),
  );
}
