import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';

/// Where the modal sits in the viewport.
enum BeuiModalPlacement {
  /// Anchored to the bottom (mobile-like, default).
  bottom,

  /// Vertically centered.
  center,
}

/// A modal whose panel **morphs height** between inner views, with a per-view
/// blur cross-fade — the Flutter port of beUI's `morphing-modal`, built on
/// [BeuiOverlay].
///
/// Driven by [viewId]: a non-null id opens the modal showing [child]; changing
/// [viewId] (while open) cross-fades the view (blur + rise) and springs the
/// panel's height to the new content. `null` closes it. The panel enters with
/// opacity + rise + scale over a frosted backdrop; reduced motion fades opacity
/// only.
class BeuiMorphingModal extends StatelessWidget {
  /// Creates a morphing modal showing [child] for the current [viewId].
  const BeuiMorphingModal({
    required this.viewId,
    required this.onClose,
    required this.child,
    this.placement = BeuiModalPlacement.bottom,
    super.key,
  });

  /// The current view's id; `null` closes the modal.
  final String? viewId;

  /// Called when the backdrop is tapped or Esc is pressed.
  final VoidCallback onClose;

  /// The current view's content.
  final Widget child;

  /// Bottom-anchored or centered.
  final BeuiModalPlacement placement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    return BeuiOverlay(
      open: viewId != null,
      barrier: true,
      barrierColor: colors.background.withValues(
        alpha: 0.05,
      ), // bg-background/5
      barrierBlur: 14, // backdrop blur(14px)
      onDismiss: onClose,
      enterDuration: const Duration(milliseconds: 300),
      exitDuration: const Duration(milliseconds: 200),
      overlayBuilder: (context, animation, link) =>
          _panel(context, animation, colors),
      child: const SizedBox.shrink(),
    );
  }

  Widget _panel(
    BuildContext context,
    Animation<double> animation,
    BeuiColors colors,
  ) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isBottom = placement == BeuiModalPlacement.bottom;
    final width = math.min(384.0, MediaQuery.of(context).size.width - 32);
    final enterY = reduce ? 0.0 : (isBottom ? 40.0 : 20.0);
    final enterScale = reduce ? 1.0 : 0.97;
    final scaleOrigin = isBottom ? Alignment.bottomCenter : Alignment.center;

    // RepaintBoundary isolates the panel's per-frame repaints (morph, view
    // blur, enter transform) from the full-screen backdrop layer, so the
    // expensive BackdropFilter isn't re-rasterised while the panel animates.
    final surface = RepaintBoundary(
      child: Container(
        key: const ValueKey('beui_modal_panel'),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(24), // rounded-3xl
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 40,
              offset: Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias, // overflow-hidden
        child: AnimatedSize(
          // SPRING_PANEL is overdamped (no overshoot) ≈ a gentle easeOut. Use a
          // smooth curve here, NOT the source's aggressive EASE_OUT (which is
          // for its curve-based animations, not the panel's spring).
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.all(20), // p-5
            child: AnimatedSwitcher(
              // Linear, equal in/out so the two views blend ~50/50 at the
              // midpoint (a true cross-fade); the y-roll + blur are eased
              // inside the transition.
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 220),
              switchInCurve: Curves.linear,
              switchOutCurve: Curves.linear,
              // popLayout: the entering view (behind) sizes the panel so it
              // morphs to the new height; the exiting view is pinned ON TOP and
              // lifts away to reveal the new one — a true cross-fade.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  ?currentChild,
                  for (final c in previousChildren)
                    Positioned(left: 0, right: 0, top: 0, child: c),
                ],
              ),
              transitionBuilder: (child, a) =>
                  _viewTransition(child, a, reduce),
              child: KeyedSubtree(key: ValueKey(viewId), child: child),
            ),
          ),
        ),
      ),
    );

    return Align(
      alignment: isBottom ? Alignment.bottomCenter : Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: isBottom ? 32 : 0,
        ),
        child: SizedBox(
          width: width,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final t = animation.value.clamp(0.0, 1.0);
              final e = Curves.easeOutCubic.transform(t); // ~SPRING_PANEL
              return Opacity(
                opacity: Curves.easeOut.transform(t),
                child: Transform.translate(
                  offset: Offset(0, (1 - e) * enterY),
                  child: Transform.scale(
                    scale: enterScale + (1 - enterScale) * e,
                    alignment: scaleOrigin,
                    child: child,
                  ),
                ),
              );
            },
            child: surface,
          ),
        ),
      ),
    );
  }

  Widget _viewTransition(
    Widget child,
    Animation<double> animation,
    bool reduce,
  ) {
    if (reduce) return FadeTransition(opacity: animation, child: child);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value.clamp(0.0, 1.0);
        // Entering views rise from below (y: 8 → 0); exiting views rise up and
        // out (y: 0 → -8) — one continuous upward roll, the source's
        // popLayout cross-fade. Source blur(4px) ≈ sigma ~2.5.
        final exiting =
            animation.status == AnimationStatus.reverse ||
            animation.status == AnimationStatus.dismissed;
        final dir = exiting ? -1.0 : 1.0;
        final eased = Curves.easeOut.transform(t);
        final blur = (1 - eased) * 2.5;
        return Opacity(
          opacity: t, // linear → balanced cross-fade
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 8 * dir),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.decal,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
