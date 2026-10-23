import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the volume profile.
Widget volumeProfileDemo(BuildContext context) => const _VolumeProfileDemo();

class _VolumeProfileDemo extends StatefulWidget {
  const _VolumeProfileDemo();

  @override
  State<_VolumeProfileDemo> createState() => _VolumeProfileDemoState();
}

class _VolumeProfileDemoState extends State<_VolumeProfileDemo> {
  String _session = 'Today';
  static const _sessions = {
    'Today': volumes,
    'Previous': [
      6,
      9,
      13,
      18,
      27,
      40,
      56,
      74,
      95,
      114,
      146,
      188,
      242,
      286,
      253,
      208,
      165,
      126,
      92,
      65,
      42,
      30,
      21,
      14,
    ],
    'Week': [
      75,
      104,
      143,
      214,
      305,
      382,
      494,
      626,
      795,
      902,
      1028,
      1182,
      1097,
      973,
      825,
      695,
      589,
      481,
      372,
      289,
      195,
      154,
      119,
      84,
    ],
  };
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
    final volumes = _sessions[_session]!;
    final data = [
      for (var i = 0; i < volumes.length; i++)
        BeuiVolumeProfileBin.range(
          id: 'price-${64000 + i * 100}',
          priceLow: 64000 + i * 100,
          priceHigh: 64100 + i * 100,
          volume: volumes[i].toDouble(),
        ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'BTC / USD',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Volume by price · Demo data',
                      style: TextStyle(
                        fontSize: 12,
                        height: 4 / 3,
                        color: BeuiColors.resolve(context).mutedForeground,
                      ),
                    ),
                  ],
                ),
                BeuiTabs<String>(
                  value: _session,
                  onChanged: (value) => setState(() => _session = value),
                  variant: BeuiTabsVariant.segment,
                  triggerPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  tabs: [
                    for (final name in _sessions.keys)
                      BeuiTab(
                        value: name,
                        label: Text(name, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            BeuiVolumeProfile(
              data: data,
              label: 'BTC volume profile',
              unit: 'BTC',
              formatPrice: (v) => '\$${beuiChartFormatNumber(v)}',
              formatVolume: (v) => beuiChartFormatNumber(
                v,
                maximumFractionDigits: v == v.roundToDouble() ? 0 : 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BeuiVolumeProfilePlot(
                    height: MediaQuery.sizeOf(context).width < 640 ? 288 : 320,
                  ),
                  const BeuiVolumeProfileTooltip(),
                  const SizedBox(height: 20),
                  const BeuiVolumeProfileSummary(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
