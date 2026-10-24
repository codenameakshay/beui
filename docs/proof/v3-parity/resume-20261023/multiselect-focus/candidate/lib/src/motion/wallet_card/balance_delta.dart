import 'package:flutter/material.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_format.dart';

/// A transient change indicator for the balance: a tinted pill with a trend
/// arrow that pops in whenever the balance moves and persists until it moves
/// again — the Flutter port of the source's `BalanceDelta`.
///
/// The pill enters `{opacity:0, y:6, scale:0.9} → {1, 0, 1}` and leaves
/// `→ {opacity:0, y:-6, scale:0.9}`, each over 200ms `EASE_OUT` (source
/// transition). Reduced motion keeps the opacity cross-fade but drops the
/// translate/scale.
class WalletBalanceDelta extends StatefulWidget {
  /// Creates a balance-delta indicator.
  const WalletBalanceDelta({
    required this.balance,
    this.initialChange,
    super.key,
  });

  /// The current balance; a change from the previous value fires a new pill.
  final double balance;

  /// Initial change shown before any live movement (source `initialChange`).
  final double? initialChange;

  @override
  State<WalletBalanceDelta> createState() => _WalletBalanceDeltaState();
}

class _Delta {
  const _Delta(this.id, this.amount);
  final int id;
  final double amount;
}

class _WalletBalanceDeltaState extends State<WalletBalanceDelta> {
  late double _prev = widget.balance;
  late _Delta? _delta = widget.initialChange != null
      ? _Delta(0, widget.initialChange!)
      : null;
  int _seq = 0;

  @override
  void didUpdateWidget(WalletBalanceDelta old) {
    super.didUpdateWidget(old);
    final diff = widget.balance - _prev;
    _prev = widget.balance;
    if (diff == 0) return;
    setState(() => _delta = _Delta(++_seq, diff));
  }

  String _formatMoney(double v) {
    final whole = v.truncate();
    final cents = ((v - whole).abs() * 100).round().toString().padLeft(2, '0');
    final grouped = beuiGroupThousands(whole.abs().toString());
    return '$grouped.$cents';
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final delta = _delta;
    final up = (delta?.amount ?? 0) > 0;
    final tone = up ? colors.success : colors.destructive;

    // Source row is `mt-2 flex h-7 items-center justify-center`.
    return Container(
      margin: const EdgeInsets.only(top: 8), // mt-2
      height: 28, // h-7
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: beuiEaseOut,
          switchOutCurve: beuiEaseOut,
          transitionBuilder: (child, animation) {
            final fade = FadeTransition(opacity: animation, child: child);
            if (reduce) return fade;
            final entering = animation.status != AnimationStatus.reverse;
            return AnimatedBuilder(
              animation: animation,
              builder: (context, inner) {
                final t = animation.value;
                // enter rises from +6; exit lifts up to −6.
                final dy = entering ? (1 - t) * 6 : (1 - t) * -6;
                final scale = 0.9 + 0.1 * t;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(scale: scale, child: inner),
                );
              },
              child: fade,
            );
          },
          child: delta == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : Container(
                  key: ValueKey(delta.id),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        up
                            ? LucideIcons.trending_up
                            : LucideIcons.trending_down,
                        size: 14,
                        color: tone,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${up ? '+' : '-'}\$${_formatMoney(delta.amount)}',
                        style: TextStyle(
                          fontSize: 12, // text-xs
                          height: 16 / 12, // …/16
                          fontWeight: FontWeight.w600,
                          color: tone,
                          fontFeatures: const [FontFeature.tabularFigures()],
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
