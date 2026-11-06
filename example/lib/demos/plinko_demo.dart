import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Source-preview gallery state for Plinko.
class PlinkoDemo extends StatefulWidget {
  /// Creates the preview demo.
  const PlinkoDemo({super.key});

  @override
  State<PlinkoDemo> createState() => _PlinkoDemoState();
}

class _PlinkoDemoState extends State<PlinkoDemo> {
  String _rows = '12';
  num _score = 0;
  int _drops = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 576),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeuiTabs<String>(
            value: _rows,
            variant: BeuiTabsVariant.pill,
            onChanged: (value) => setState(() => _rows = value),
            tabs: const [
              BeuiTab(value: '8', label: Text('8 rows')),
              BeuiTab(value: '12', label: Text('12 rows')),
              BeuiTab(value: '16', label: Text('16 rows')),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: TextStyle(
                color: BeuiColors.resolve(context).mutedForeground,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              children: [
                const TextSpan(text: 'Score '),
                TextSpan(
                  text: '$_score',
                  style: TextStyle(
                    color: BeuiColors.resolve(context).foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: '  ·  $_drops ${_drops == 1 ? 'ball' : 'balls'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BeuiPlinko(
            rows: int.parse(_rows),
            onLand: (_, value) => setState(() {
              _score += value is num
                  ? value
                  : num.tryParse(value.toString()) ?? 0;
              _drops++;
            }),
          ),
        ],
      ),
    ),
  );
}
