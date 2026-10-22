import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Preview for the liquidity heatmap.
Widget liquidityHeatmapDemo(BuildContext context) =>
    const _LiquidityHeatmapDemo();

class _LiquidityHeatmapDemo extends StatelessWidget {
  const _LiquidityHeatmapDemo();

  @override
  Widget build(BuildContext context) {
    final snapshots = List.generate(24, (time) {
      return BeuiLiquiditySnapshot(
        id: 'minute-$time',
        label: '14:${(time * 2).toString().padLeft(2, '0')}',
        price: 245.5 + math.sin(time * .27) * 1.2 + time * .035,
        levels: List.generate(18, (row) {
          final shelf =
              math.exp(-math.pow(row - 4 - math.sin(time * .18) * .7, 2) / .8) +
              math.exp(
                -math.pow(row - 13 + math.cos(time * .15) * .8, 2) / 1.2,
              );
          final noise = (math.sin(row * 12.9 + time * 7.3) + 1) / 2;
          return BeuiLiquidityLevel(
            price: 250 - row * .5,
            size:
                (90 + noise * 350 + shelf * (1500 + math.sin(time * .3) * 450))
                    .roundToDouble(),
          );
        }),
      );
    });
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BeuiLiquidityHeatmap(
            snapshots: snapshots,
            maxSize: 2400,
            unit: 'SOL',
            label: 'Simulated SOL liquidity heatmap',
            formatPrice: (price) => '\$${price.toStringAsFixed(2)}',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Where liquidity rests',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 3),
                Text(
                  'SOL / USD · Simulated depth',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 14),
                BeuiLiquidityPlot(),
                SizedBox(height: 12),
                BeuiLiquidityLegend(),
                SizedBox(height: 8),
                Text(
                  'Brighter bands hold more liquidity · White line tracks price',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
