import 'package:flutter/material.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart' show SingleMotionBuilder;

/// A single wallet action (icon-over-label).
@immutable
class _WalletAction {
  const _WalletAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

/// Row of primary wallet actions rendered icon-over-label, with a spring press
/// — the Flutter port of the source's `WalletActions`.
///
/// Each button squishes to `scale 0.94` while pressed on [beuiSpringPress]
/// (source `whileTap={{ scale: 0.94 }} transition={SPRING_PRESS}`). Reduced
/// motion drops the squish.
class WalletActions extends StatelessWidget {
  /// Creates the actions row.
  const WalletActions({
    this.onSend,
    this.onDeposit,
    this.onSwap,
    this.onBuy,
    super.key,
  });

  /// Tap callbacks for the four actions.
  final VoidCallback? onSend;
  final VoidCallback? onDeposit;
  final VoidCallback? onSwap;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final actions = <_WalletAction>[
      _WalletAction('Send', LucideIcons.arrow_up, onSend),
      _WalletAction('Deposit', LucideIcons.arrow_down_to_line, onDeposit),
      _WalletAction('Swap', LucideIcons.repeat, onSwap),
      _WalletAction('Buy', LucideIcons.credit_card, onBuy),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in actions)
          Expanded(child: _WalletActionButton(action: a)),
      ],
    );
  }
}

class _WalletActionButton extends StatefulWidget {
  const _WalletActionButton({required this.action});
  final _WalletAction action;

  @override
  State<_WalletActionButton> createState() => _WalletActionButtonState();
}

class _WalletActionButtonState extends State<_WalletActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final target = (_pressed && !reduce) ? 0.94 : 1.0;

    return Semantics(
      button: true,
      label: widget.action.label,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.action.onTap,
          child: SingleMotionBuilder(
            value: target,
            motion: beuiSpringPress,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.muted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.action.icon,
                    size: 20,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.action.label,
                  style: TextStyle(
                    fontSize: 12, // text-xs
                    height: 16 / 12, // …/16
                    fontWeight: FontWeight.w500,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
