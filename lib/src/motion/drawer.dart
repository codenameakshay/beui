import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';

/// Which edge the drawer slides from.
enum BeuiDrawerSide {
  /// Slides in from the left.
  left,

  /// Slides in from the right (default).
  right,
}

/// An edge drawer — the Flutter port of beUI's `drawer`, built on [BeuiOverlay].
///
/// A modal panel (320px, capped at 85% of the screen) that slides in from the
/// [side] over a fading, blurred backdrop. Closes on backdrop tap (when
/// [dismissible]) or Esc; focus is trapped while open.
///
/// **Controlled** ([open] + [onOpenChange]), the source's API. The panel slide
/// uses the overdamped panel spring (`SPRING_PANEL`, approximated with
/// `EASE_OUT` here); reduced motion fades opacity instead of sliding.
class BeuiDrawer extends StatelessWidget {
  /// Creates a drawer whose [child] is the panel content.
  const BeuiDrawer({
    required this.open,
    required this.onOpenChange,
    required this.child,
    this.side = BeuiDrawerSide.right,
    this.dismissible = true,
    this.label,
    super.key,
  });

  /// Whether the drawer is open (controlled).
  final bool open;

  /// Called when the drawer requests to close (backdrop tap / Esc).
  final ValueChanged<bool> onOpenChange;

  /// The panel content.
  final Widget child;

  /// Which edge to slide from.
  final BeuiDrawerSide side;

  /// Whether tapping the backdrop closes the drawer.
  final bool dismissible;

  /// Accessibility label for the dialog.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return BeuiOverlay(
      open: open,
      barrier: true,
      barrierColor: const Color(0x66000000), // bg-black/40
      barrierBlur: 4, // backdrop-blur-sm
      barrierDismissible: dismissible,
      onDismiss: () => onOpenChange(false),
      enterDuration: const Duration(milliseconds: 300),
      exitDuration: const Duration(milliseconds: 220),
      overlayBuilder: (context, animation, link) =>
          _panel(context, animation),
      child: const SizedBox.shrink(),
    );
  }

  Widget _panel(BuildContext context, Animation<double> animation) {
    final theme = Theme.of(context);
    final colors = theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isRight = side == BeuiDrawerSide.right;
    final width = math.min(320.0, MediaQuery.of(context).size.width * 0.85);

    final surface = Material(
      key: const ValueKey('beui_drawer_panel'),
      type: MaterialType.transparency,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: label,
        explicitChildNodes: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            border: Border(
              left: isRight
                  ? BorderSide(color: colors.border)
                  : BorderSide.none,
              right: isRight
                  ? BorderSide.none
                  : BorderSide(color: colors.border),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x40000000),
                blurRadius: 30,
                offset: Offset(isRight ? -8 : 8, 0),
              ),
            ],
          ),
          child: SizedBox.expand(child: child),
        ),
      ),
    );

    return Positioned(
      top: 0,
      bottom: 0,
      left: isRight ? null : 0,
      right: isRight ? 0 : null,
      width: width,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value.clamp(0.0, 1.0);
          if (reduce) {
            return Opacity(opacity: Curves.easeOut.transform(t), child: child);
          }
          final e = beuiEaseOut.transform(t);
          final dx = (1 - e) * (isRight ? width : -width); // off-edge → 0
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: surface,
      ),
    );
  }
}
