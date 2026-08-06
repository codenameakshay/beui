import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// One expandable view of a [BeuiDynamicIsland] (source `DynamicIslandView`).
@immutable
class BeuiDynamicIslandView {
  /// Creates an island view.
  const BeuiDynamicIslandView({required this.id, required this.child});

  /// Matches [BeuiDynamicIsland.view] when active.
  final String id;

  /// The expanded content (rendered with the source's `px-6 py-4` padding).
  final Widget child;
}

// Shell physics in Apple's duration/bounce form — one long perceptual glide
// with barely-there bounce, identical in both directions (source SHELL_SPRING
// {duration: 0.8, bounce: 0.2}). Converted with Framer's decay-envelope solve
// ((ζ/√(1−ζ²))·e^(−ζω₀·d) = 0.001): ζ = 0.8, ω₀ ≈ 11.24 → k ≈ 126.4,
// c ≈ 17.99 (mass 1).
const _shellSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 126.4, damping: 17.99),
);

// Content gets a touch more life than the shell (source CONTENT_SPRING
// {duration: 0.8, bounce: 0.35}): ζ = 0.65, ω₀ ≈ 12.98 → k ≈ 168.6, c ≈ 16.88.
const _contentSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 168.6, damping: 16.88),
);

/// Constant radius — never animated. Clamped to half the shell height in
/// paint, so the pill-to-rounded-rect morph falls out of the resize for free.
const _radius = 32.0;

/// iPhone pill dimensions; also the shell's pre-measure target so a
/// first-frame-active view blooms from the pill.
const _pillSize = Size(126, 37);

/// iOS-style Dynamic Island: a pill that springs open into live-activity
/// views — the Flutter port of beUI's `DynamicIsland`.
///
/// The shell animates real width/height (not transforms) toward the active
/// content's natural size, so slots are never scale-distorted; the corner
/// radius stays constant. Content unfurls downward out of the pill on a
/// livelier spring and is sucked back up on exit (80ms, faster than the
/// shell can clip it).
///
/// Reduced motion snaps the shell size and swaps content with plain fades.
class BeuiDynamicIsland extends StatefulWidget {
  /// Creates a dynamic island.
  const BeuiDynamicIsland({
    required this.view,
    this.compact,
    this.views = const [],
    super.key,
  });

  /// Active view id; `null` shows the compact pill.
  final String? view;

  /// Compact pill content, shown when no view is active.
  final Widget? compact;

  /// The expandable views.
  final List<BeuiDynamicIslandView> views;

  @override
  State<BeuiDynamicIsland> createState() => _BeuiDynamicIslandState();
}

class _BeuiDynamicIslandState extends State<BeuiDynamicIsland> {
  final GlobalKey _sizerKey = GlobalKey();
  Size? _contentSize;

  /// The source's ResizeObserver: track the natural size of the live content
  /// so the shell can spring to it.
  void _scheduleMeasure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _sizerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      if (box.size != _contentSize) {
        setState(() => _contentSize = box.size);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final active = widget.view == null
        ? null
        : widget.views.where((v) => v.id == widget.view).firstOrNull;
    _scheduleMeasure();

    // The sizer holds only the incoming slot in layout (exiting slots are
    // lifted out of flow, the popLayout contract), so it reports the natural
    // size the shell should spring toward.
    final sizer = KeyedSubtree(
      key: _sizerKey,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 900), // > spring settle
        reverseDuration: const Duration(milliseconds: 80),
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) =>
            _SlotTransition(animation: animation, reduce: reduce, child: child),
        layoutBuilder: (current, previous) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Exiting slots leave layout immediately (source popLayout).
            for (final p in previous) Positioned(top: 0, child: p),
            ?current,
          ],
        ),
        child: active != null
            ? KeyedSubtree(
                key: ValueKey('view-${active.id}'),
                child: _MinContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ), // px-6 py-4
                    child: active.child,
                  ),
                ),
              )
            : widget.compact != null
            ? KeyedSubtree(
                key: const ValueKey('compact'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: _pillSize.width,
                    minHeight: _pillSize.height,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ), // px-4 py-1.5
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 12, // text-xs
                          fontWeight: FontWeight.w500,
                          color: colors.background,
                        ),
                        child: widget.compact!,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(key: ValueKey('empty')),
      ),
    );

    return Semantics(
      container: true,
      liveRegion: true, // role="status" aria-live="polite"
      child: MotionBuilder<Size>(
        value: _contentSize ?? _pillSize,
        from: _pillSize,
        converter: const SizeMotionConverter(),
        motion: reduce ? const NoMotion() : _shellSpring,
        builder: (context, size, child) {
          // NoMotion freezes rather than snaps — place directly at target.
          final s = reduce ? (_contentSize ?? _pillSize) : size;
          return Container(
            width: s.width,
            height: s.height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.foreground,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: const [
                // shadow-2xl
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 50,
                  offset: Offset(0, 25),
                  spreadRadius: -12,
                ),
              ],
            ),
            // items-start: content pins to the top edge while the shell
            // springs, so expansion unfurls downward out of the pill.
            child: OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: colors.background),
                child: IconTheme.merge(
                  data: IconThemeData(color: colors.background),
                  child: child!,
                ),
              ),
            ),
          );
        },
        child: sizer,
      ),
    );
  }
}

/// Lays the child out at its **minimum** intrinsic width — CSS `min-content`.
///
/// The source's sizer is `w-max` (max-content) but it is also a flex item of
/// the shell, and a flex item shrinks to its min-content width when the
/// container is narrower. Because the shell's width is driven *from* the
/// sizer's measured width, the two settle at a fixed point: the shell always
/// comes to rest at the content's min-content width, whichever view it came
/// from. That is what beui.dev renders — "INCOMING / CALL" and "Midnight /
/// City" wrap at the longest word — so the port has to size the same way,
/// not at Flutter's natural max-intrinsic width.
class _MinContentWidth extends SingleChildRenderObjectWidget {
  const _MinContentWidth({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinContentWidth();
}

class _RenderMinContentWidth extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  BoxConstraints _minContent(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints;
    final width = constraints.constrainWidth(
      child.getMinIntrinsicWidth(double.infinity),
    );
    return constraints.tighten(width: width);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return child.getDryLayout(_minContent(constraints));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_minContent(constraints), parentUsesSize: true);
    size = child.size;
  }
}

/// One spring drives transform, opacity and blur together on enter
/// (source `Slot`): opacity 0→1, scale 0.9→1, y -8→0, blur 5px→0, origin top
/// center. Exit is sucked up into the pill — 80ms, blur-free. Reduced motion
/// keeps fades only.
class _SlotTransition extends StatelessWidget {
  const _SlotTransition({
    required this.animation,
    required this.reduce,
    required this.child,
  });

  final Animation<double> animation;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduce) return FadeTransition(opacity: animation, child: child);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final exiting = animation.status == AnimationStatus.reverse;
        if (exiting) {
          final t = beuiEaseOut.transform(animation.value);
          return Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -6 * (1 - t)),
              child: Transform.scale(
                scale: 0.9 + 0.1 * t,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
          );
        }
        // Entering: ride the content spring, not the switcher clock.
        return SingleMotionBuilder(
          value: 1.0,
          from: 0.0,
          motion: _contentSpring,
          builder: (context, t, inner) {
            final clamped = t.clamp(0.0, 1.0);
            final sigma = 2.5 * (1 - clamped); // blur(5px) ≈ σ2.5
            Widget body = inner!;
            if (sigma > 0.05) {
              body = ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.decal,
                ),
                child: body,
              );
            }
            return Opacity(
              opacity: clamped,
              child: Transform.translate(
                offset: Offset(0, -8 * (1 - t)),
                child: Transform.scale(
                  scale: 0.9 + 0.1 * t,
                  alignment: Alignment.topCenter,
                  child: body,
                ),
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}
