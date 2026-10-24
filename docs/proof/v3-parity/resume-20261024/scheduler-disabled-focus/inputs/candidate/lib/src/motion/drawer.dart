import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder;

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
/// rides the overdamped panel spring (`SPRING_PANEL`) toward its current
/// target — in place when open, off-screen when closing — so enter and exit
/// are the *same spring played forward*, matching the source. The backdrop
/// fades over 250ms `EASE_OUT` in both directions. Reduced motion fades
/// opacity (200ms `EASE_OUT`) instead of sliding.
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    return BeuiOverlay(
      open: open,
      barrier: true,
      barrierColor: const Color(0x66000000), // bg-black/40
      barrierBlur: 2, // backdrop-blur-sm (4px) → σ2
      barrierDismissible: dismissible,
      // The backdrop fades over 250ms EASE_OUT in both directions (source).
      barrierEnterDuration: Duration(milliseconds: reduce ? 200 : 250),
      barrierExitDuration: Duration(milliseconds: reduce ? 200 : 250),
      barrierCurve: beuiEaseOut,
      onDismiss: () => onOpenChange(false),
      // Lifecycle envelope, not the slide's clock — the panel rides
      // SPRING_PANEL (see _panel); 400ms keeps the portal mounted until the
      // exit spring has visually settled. Reduced motion: 200ms opacity fade.
      enterDuration: Duration(milliseconds: reduce ? 200 : 400),
      exitDuration: Duration(milliseconds: reduce ? 200 : 400),
      overlayBuilder: (context, animation, link) => _panel(context, animation),
      child: const SizedBox.shrink(),
    );
  }

  Widget _panel(BuildContext context, Animation<double> animation) {
    final colors = BeuiColors.resolve(context);
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

    if (reduce) {
      return Positioned(
        top: 0,
        bottom: 0,
        left: isRight ? null : 0,
        right: isRight ? 0 : null,
        width: width,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Opacity(
            opacity: beuiEaseOut.transform(animation.value.clamp(0.0, 1.0)),
            child: child,
          ),
          child: surface,
        ),
      );
    }

    final offX = isRight ? width : -width; // off-screen resting x
    return Positioned(
      top: 0,
      bottom: 0,
      left: isRight ? null : 0,
      right: isRight ? 0 : null,
      width: width,
      child: SingleMotionBuilder(
        // SPRING_PANEL drives the slide in BOTH directions (source): the
        // target is 0 while open and the off-screen edge while closing, so
        // the exit is the same spring played forward, not a reversed enter.
        value: open ? 0.0 : offX,
        from: offX,
        motion: beuiSpringPanel,
        builder: (context, dx, child) =>
            Transform.translate(offset: Offset(dx, 0), child: child),
        child: surface,
      ),
    );
  }
}
