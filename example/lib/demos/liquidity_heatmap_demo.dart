import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Preview for the liquidity heatmap.
Widget liquidityHeatmapDemo(BuildContext context) =>
    const _LiquidityHeatmapDemo();

class _LiquidityHeatmapDemo extends StatefulWidget {
  const _LiquidityHeatmapDemo();

  @override
  State<_LiquidityHeatmapDemo> createState() => _LiquidityHeatmapDemoState();
}

class _LiquidityHeatmapDemoState extends State<_LiquidityHeatmapDemo> {
  int _phase = 0;

  @override
  Widget build(BuildContext context) {
    final snapshots = List.generate(24, (time) {
      return BeuiLiquiditySnapshot(
        id: 'minute-$time',
        label: '14:${(time * 2).toString().padLeft(2, '0')}',
        price: 245.5 + math.sin(time * .27 + _phase * .4) * 1.2 + time * .035,
        levels: List.generate(18, (row) {
          final shelf =
              math.exp(
                -math.pow(row - 4 - math.sin(time * .18 + _phase) * .7, 2) / .8,
              ) +
              math.exp(
                -math.pow(row - 13 + math.cos(time * .15 + _phase) * .8, 2) /
                    1.2,
              );
          final noise =
              (math.sin(row * 12.9 + time * 7.3 + _phase * 2.1) + 1) / 2;
          return BeuiLiquidityLevel(
            price: 250 - row * .5,
            size:
                (90 +
                        noise * 350 +
                        shelf * (1500 + math.sin(time * .3 + _phase) * 450))
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Where liquidity rests',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    BeuiButton(
                      variant: BeuiButtonVariant.ghost,
                      size: BeuiButtonSize.sm,
                      onPressed: () => setState(() => _phase++),
                      child: const Text('Resimulate'),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'SOL / USD · Simulated depth',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                const BeuiLiquidityPlot(),
                const SizedBox(height: 12),
                const BeuiLiquidityLegend(),
                const SizedBox(height: 8),
                const Text(
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
