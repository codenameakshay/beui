import 'dart:async';
import 'dart:math';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery entry for the `number` component — the slot-machine [BeuiNumberTicker]
/// and the in-view count-up [BeuiAnimatedNumber]. Ports the two preview bands on
/// beui.dev/components/motion/number: `NumberTickerPreview` and
/// `AnimatedNumberPreview`, both `flex flex-col items-center gap-3`.
Widget numberDemo(BuildContext context) => const _NumberDemo();

class _NumberDemo extends StatefulWidget {
  const _NumberDemo();

  @override
  State<_NumberDemo> createState() => _NumberDemoState();
}

class _NumberDemoState extends State<_NumberDemo> {
  final _rng = Random();

  static const _card = '4242 4242 4242 0806';
  static const _masked = '•••• •••• •••• 0806';
  bool _revealed = false;

  // NumberTickerPreview: "Active users" creeps up every 2.5s.
  int _users = 48273;

  Timer? _usersTimer;

  @override
  void initState() {
    super.initState();
    _usersTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) setState(() => _users += _rng.nextInt(50));
    });
  }

  @override
  void dispose() {
    _usersTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    // `text-xs text-muted-foreground` — 12/16, regular weight.
    Widget caption(String text, {Color? color}) => Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        color: color ?? colors.mutedForeground,
      ),
    );

    // `text-4xl font-semibold tracking-tight text-foreground tabular-nums`.
    final bigStyle = TextStyle(
      fontSize: 36,
      height: 40 / 36,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.9, // tracking-tight = -0.025em
      fontFeatures: const [FontFeature.tabularFigures()],
      color: colors.foreground,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                caption('Card number'),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: BeuiDigitSwap(
                    value: _revealed ? _card : _masked,
                    animationKey: _revealed ? 'revealed' : 'masked',
                    direction: _revealed
                        ? BeuiDigitSwapDirection.up
                        : BeuiDigitSwapDirection.down,
                    suffixLength: 4,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      letterSpacing: 1.4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.foreground,
                    ),
                    glyphStyle: TextStyle(
                      color: _revealed
                          ? colors.foreground
                          : colors.mutedForeground,
                    ),
                    suffixStyle: TextStyle(color: colors.foreground),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => setState(() => _revealed = !_revealed),
                  child: const Text('Animate'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 96),

        // ── NumberTickerPreview ───────────────────────────────────────────
        caption('Active users'),
        const SizedBox(height: 12), // gap-3
        BeuiNumberTicker(value: _users, locale: true, style: bigStyle),
        const SizedBox(height: 12),
        caption('live · updates every 2.5s'),

        const SizedBox(height: 96),

        // ── AnimatedNumberPreview ─────────────────────────────────────────
        caption('Monthly recurring revenue'),
        const SizedBox(height: 12),
        BeuiAnimatedNumber(
          value: 129480,
          format: (n) => '\$${groupThousands(n.round())}',
          style: bigStyle,
        ),
        const SizedBox(height: 12),
        caption('+12.4% vs last month', color: colors.success),
      ],
    );
  }
}
