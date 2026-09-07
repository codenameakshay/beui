import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart' show NoMotion, SingleMotionBuilder;

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
/// [viewId] (while open) cross-fades the view (blur + rise, 240ms in / 160ms
/// out `EASE_OUT`) and springs the panel's height to the new content on
/// `SPRING_PANEL`. `null` closes it. The panel enters with opacity + rise +
/// scale (rise/scale on `SPRING_PANEL`) over a frosted, saturated backdrop;
/// the exit eases *forward* to its own targets (opacity 0, y back out,
/// scale 0.98) over 180ms `EASE_OUT`. Reduced motion fades opacity only and
/// snaps the height.
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
    final colors = BeuiColors.resolve(context);

    return BeuiOverlay(
      open: viewId != null,
      barrier: true,
      barrierColor: colors.background.withValues(
        alpha: 0.05,
      ), // bg-background/5
      barrierBlur: 7, // backdrop blur(14px) → σ7
      barrierSaturation: 1.4, // saturate(140%), composed with the blur
      onDismiss: onClose,
      enterDuration: const Duration(milliseconds: 300),
      exitDuration: const Duration(milliseconds: 180),
      overlayBuilder: (context, animation, link) => _MorphingPanel(
        animation: animation,
        viewId: viewId,
        placement: placement,
        colors: colors,
        child: child,
      ),
      child: const SizedBox.shrink(),
    );
  }
}

class _MorphingPanel extends StatefulWidget {
  const _MorphingPanel({
    required this.animation,
    required this.viewId,
    required this.placement,
    required this.colors,
    required this.child,
  });

  final Animation<double> animation;
  final String? viewId;
  final BeuiModalPlacement placement;
  final BeuiColors colors;
  final Widget child;

  @override
  State<_MorphingPanel> createState() => _MorphingPanelState();
}

class _MorphingPanelState extends State<_MorphingPanel> {
  final GlobalKey _sizerKey = GlobalKey();
  double? _contentHeight;

  /// The source's height morph measures the active view (the ResizeObserver
  /// pattern): track the natural height of the live content so the panel can
  /// spring to it.
  void _scheduleMeasure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _sizerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      if (box.size.height != _contentHeight) {
        setState(() => _contentHeight = box.size.height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isBottom = widget.placement == BeuiModalPlacement.bottom;
    final width = math.min(384.0, MediaQuery.of(context).size.width - 32);
    final enterY = isBottom ? 40.0 : 20.0;
    final scaleOrigin = isBottom ? Alignment.bottomCenter : Alignment.center;
    _scheduleMeasure();

    // The sizer holds only the incoming view in layout (exiting views are
    // lifted out of flow, the popLayout contract), so it reports the natural
    // height the panel should spring toward.
    final sizer = KeyedSubtree(
      key: _sizerKey,
      child: Padding(
        padding: const EdgeInsets.all(20), // p-5
        child: AnimatedSwitcher(
          // Views cross-fade 240ms in / 160ms out (180/140 under reduced
          // motion); the easing lives inside the transition builder.
          duration: Duration(milliseconds: reduce ? 180 : 240),
          reverseDuration: Duration(milliseconds: reduce ? 140 : 160),
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
          transitionBuilder: (child, a) => _viewTransition(child, a, reduce),
          child: KeyedSubtree(
            key: ValueKey(widget.viewId),
            child: widget.child,
          ),
        ),
      ),
    );

    // Height morph on SPRING_PANEL (the source springs the measured height;
    // AnimatedSize can't take a spring). The first frame renders unmeasured
    // at natural height, then the post-frame measurement takes over. The
    // GlobalKey keeps the switcher's state alive across the re-wrap.
    final measured = _contentHeight;
    final Widget body = measured == null
        ? sizer
        : SingleMotionBuilder(
            value: measured,
            motion: reduce ? const NoMotion() : beuiSpringPanel,
            builder: (context, h, child) => SizedBox(
              // NoMotion freezes rather than snaps — place at target directly.
              height: reduce ? measured : h,
              // The content keeps its natural height while the box springs;
              // the panel's clip hides any overflow mid-morph.
              child: OverflowBox(
                minHeight: 0,
                maxHeight: double.infinity,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
            child: sizer,
          );

    // RepaintBoundary isolates the panel's per-frame repaints (morph, view
    // blur, enter transform) from the full-screen backdrop layer, so the
    // expensive BackdropFilter isn't re-rasterised while the panel animates.
    final surface = RepaintBoundary(
      child: Container(
        key: const ValueKey('beui_modal_panel'),
        decoration: BoxDecoration(
          color: colors.background, // source: bg-background
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
        child: body,
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
            animation: widget.animation,
            child: surface,
            builder: (context, child) {
              final t = widget.animation.value.clamp(0.0, 1.0);
              if (reduce) {
                return Opacity(
                  opacity: Curves.easeOut.transform(t),
                  child: child,
                );
              }
              final exiting =
                  widget.animation.status == AnimationStatus.reverse ||
                  widget.animation.status == AnimationStatus.dismissed;
              if (exiting) {
                // Forward exit with its OWN targets (not a reversed enter):
                // 180ms EASE_OUT to opacity 0, y back to the enter offset,
                // scale 0.98.
                final p = beuiEaseOut.transform(1 - t); // exit progress 0 → 1
                return Opacity(
                  opacity: 1 - p,
                  child: Transform.translate(
                    offset: Offset(0, enterY * p),
                    child: Transform.scale(
                      scale: 1 - 0.02 * p,
                      alignment: scaleOrigin,
                      child: child,
                    ),
                  ),
                );
              }
              // Enter: y/scale ride SPRING_PANEL; opacity rides the overlay
              // clock.
              final opacity = Curves.easeOut.transform(t);
              return SingleMotionBuilder(
                value: 1.0,
                from: 0.0,
                motion: beuiSpringPanel,
                child: child,
                builder: (context, s, inner) => Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, (1 - s) * enterY),
                    child: Transform.scale(
                      scale: 0.97 + 0.03 * s,
                      alignment: scaleOrigin,
                      child: inner,
                    ),
                  ),
                ),
              );
            },
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
      child: child,
      builder: (context, inner) {
        final t = animation.value.clamp(0.0, 1.0);
        // Entering views rise from below (y: 8 → 0); exiting views rise up
        // and out (y: 0 → -8) — one continuous upward roll, the source's
        // popLayout cross-fade. Both directions ease EASE_OUT *forward*;
        // source blur(4px) → σ2.
        final exiting =
            animation.status == AnimationStatus.reverse ||
            animation.status == AnimationStatus.dismissed;
        final double opacity;
        final double dy;
        final double blur;
        if (exiting) {
          final p = beuiEaseOut.transform(1 - t); // exit progress 0 → 1
          opacity = 1 - p;
          dy = -8.0 * p;
          blur = beuiBlurSigma(4) * p;
        } else {
          final e = beuiEaseOut.transform(t);
          opacity = e;
          dy = 8.0 * (1 - e);
          blur = beuiBlurSigma(4) * (1 - e);
        }
        Widget body = inner!;
        if (blur > 0.05) {
          body = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: body,
          );
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: body),
        );
      },
    );
  }
}
