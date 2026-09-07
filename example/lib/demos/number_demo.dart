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
