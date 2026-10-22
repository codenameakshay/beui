import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Price-target fan preview matching the source registry sample.
Widget priceTargetFanDemo(BuildContext context) => const _PriceTargetFanDemo();

class _PriceTargetFanDemo extends StatelessWidget {
  const _PriceTargetFanDemo();

  static const _history = [
    BeuiPriceHistoryPoint(date: '2025-09-14', price: 158.4),
    BeuiPriceHistoryPoint(date: '2025-10-14', price: 164.2),
    BeuiPriceHistoryPoint(date: '2025-11-14', price: 160.8),
    BeuiPriceHistoryPoint(date: '2025-12-14', price: 173.1),
    BeuiPriceHistoryPoint(date: '2026-01-14', price: 170.6),
    BeuiPriceHistoryPoint(date: '2026-02-14', price: 181.3),
    BeuiPriceHistoryPoint(date: '2026-03-14', price: 175.8),
    BeuiPriceHistoryPoint(date: '2026-04-14', price: 183.7),
    BeuiPriceHistoryPoint(date: '2026-05-14', price: 178.2),
    BeuiPriceHistoryPoint(date: '2026-06-14', price: 184.1),
    BeuiPriceHistoryPoint(date: '2026-07-14', price: 180.5),
    BeuiPriceHistoryPoint(date: '2026-08-14', price: 177.3),
    BeuiPriceHistoryPoint(date: '2026-09-14', price: 178.52),
  ];

  static const _targets = [
    BeuiPriceTarget(key: 'High', price: 232, analysts: 9),
    BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
    BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
  ];

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: const BeuiPriceTargetFan(
        current: 178.52,
        history: _history,
        targets: _targets,
        dates: BeuiPriceTargetDates(horizon: 'Sep 2027'),
      ),
    ),
  );
}
