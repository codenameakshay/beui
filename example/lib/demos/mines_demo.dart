import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery preview of the source Mines scenario and its best-cash-out counter.
class MinesDemo extends StatefulWidget {
  const MinesDemo({super.key});

  @override
  State<MinesDemo> createState() => _MinesDemoState();
}

class _MinesDemoState extends State<MinesDemo> {
  double _best = 0;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                text: 'Best cash out  ',
                children: [
                  TextSpan(
                    text: beuiFormatMinesMultiplier(_best),
                    style: TextStyle(
                      color: colors.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                color: colors.mutedForeground,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            BeuiMines(
              onCashOut: (multiplier, _) => setState(() {
                _best = multiplier > _best ? multiplier : _best;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
