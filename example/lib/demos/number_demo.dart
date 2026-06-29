import 'dart:async';
import 'dart:math';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the `number` component — the slot-machine [BeuiNumberTicker]
/// and the in-view count-up [BeuiAnimatedNumber]. Replicates the source's
/// `number-ticker`, `animated-number`, and combined `number` previews.
Widget numberDemo(BuildContext context) => const _NumberDemo();

class _NumberDemo extends StatefulWidget {
  const _NumberDemo();

  @override
  State<_NumberDemo> createState() => _NumberDemoState();
}

class _NumberDemoState extends State<_NumberDemo> {
  final _rng = Random();

  // number-ticker.preview: "Active users" creeps up every 2.5s.
  int _users = 48273;
  // number.preview hero: ticker ⇄ animated, swapping every 3s.
  bool _showAnimated = false;

  Timer? _usersTimer;
  Timer? _swapTimer;

  @override
  void initState() {
    super.initState();
    _usersTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) setState(() => _users += _rng.nextInt(50));
    });
    _swapTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _showAnimated = !_showAnimated);
    });
  }

  @override
  void dispose() {
    _usersTimer?.cancel();
    _swapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    // The source preview's `--color-success` (no token in BeuiColors).
    const success = Color(0xFF16A34A);

    Widget caption(String text, {Color? color}) => Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: color ?? colors.mutedForeground,
      ),
    );

    final bigStyle = TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: colors.foreground,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // number-ticker.preview — live "Active users".
        caption('Number ticker — slot-machine digits (live, every 2.5s)'),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            caption('Active users'),
            const SizedBox(height: 6),
            BeuiNumberTicker(
              value: _users,
              locale: true,
              blur: true,
              style: bigStyle,
            ),
            const SizedBox(height: 6),
            caption('live · updates every 2.5s'),
          ],
        ),
        const SizedBox(height: 44),

        // animated-number.preview — MRR count-up.
        caption('Animated number — in-view count-up (a tween, EASE_OUT)'),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            caption('Monthly recurring revenue'),
            const SizedBox(height: 6),
            BeuiAnimatedNumber(
              value: 129480,
              format: (n) => '\$${_grouped(n.round())}',
              style: bigStyle,
            ),
            const SizedBox(height: 6),
            caption('+12.4% vs last month', color: success),
          ],
        ),
        const SizedBox(height: 44),

        // number.preview — hero auto-cycling ticker ⇄ animated with blur fade.
        caption('Combined — auto-cycles ticker ⇄ animated every 3s'),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: beuiEaseOut,
              switchOutCurve: beuiEaseOut,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _showAnimated
                  ? _heroBlock(
                      key: const ValueKey('animated'),
                      label: 'Revenue',
                      value: BeuiAnimatedNumber(
                        value: 129480,
                        format: (n) => '\$${_grouped(n.round())}',
                        style: bigStyle,
                      ),
                      colors: colors,
                    )
                  : _heroBlock(
                      key: const ValueKey('ticker'),
                      label: 'Active users',
                      value: BeuiNumberTicker(
                        value: _users,
                        locale: true,
                        style: bigStyle,
                      ),
                      colors: colors,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroBlock({
    required Key key,
    required String label,
    required Widget value,
    required BeuiColors colors,
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 12, color: colors.mutedForeground),
      ),
      const SizedBox(height: 6),
      value,
    ],
  );

  static String _grouped(int value) {
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return value < 0 ? '-$buf' : buf.toString();
  }
}
