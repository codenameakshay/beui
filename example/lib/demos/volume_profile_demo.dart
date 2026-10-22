import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the volume profile.
Widget volumeProfileDemo(BuildContext context) => const _VolumeProfileDemo();

class _VolumeProfileDemo extends StatelessWidget {
  const _VolumeProfileDemo();
  static const volumes = [
    18,
    27,
    36,
    52,
    70,
    96,
    135,
    172,
    205,
    241,
    278,
    225,
    192,
    146,
    108,
    79,
    56,
    42,
    31,
    22,
    16,
    11,
    8,
    5,
  ];
  @override
  Widget build(BuildContext context) {
    final data = [
      for (var i = 0; i < volumes.length; i++)
        BeuiVolumeProfileBin(
          price: 64050 + i * 100,
          volume: volumes[i].toDouble(),
        ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('BTC / USD'),
            const SizedBox(height: 4),
            Text(
              'Volume by price · Demo data',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            BeuiVolumeProfile(
              data: data,
              label: 'BTC volume profile',
              unit: 'BTC',
              formatPrice: (v) => '\$${beuiChartFormatNumber(v)}',
            ),
          ],
        ),
      ),
    );
  }
}
