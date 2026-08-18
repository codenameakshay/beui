/// Focus-ring helper — paints a visible focus indicator without moving the
/// thing it is indicating.
///
/// Package-internal. Not exported from `lib/beui.dart`.
///
/// Two bugs, one widget. The audit found focus rings implemented as a border
/// swap inside a `BoxDecoration`: because a border is part of the box model, a
/// 2px ring both **insets the child by 2px** — the "focus indicator" is a
/// layout jitter, and a paragraph reflows when an inline citation marker takes
/// focus — and was drawn in [BeuiColors.ring], a 6-12% hairline token that
/// composites to 1.30:1 against the background where WCAG 2.2 SC 1.4.11 wants
/// 3:1.
///
/// This paints the ring in the foreground, outside layout, in the dedicated
/// [BeuiColors.focusRing] role.
library;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Focus-ring fade, 150ms `EASE_OUT`, matching the existing focus transitions
/// in `input.dart` and `message_bubble.dart`.
const beuiFocusRingMotion = CurvedMotion(
  Duration(milliseconds: 150),
  beuiEaseOut,
);

/// Ring thickness, in logical pixels (source `ring-2`).
const double beuiFocusRingWidth = 2;

/// Overlays a focus ring on [child] when [focused], leaving layout untouched.
///
/// The ring is a foreground overlay inside a `Stack` sized by [child], so the
/// child's constraints, size, and painted position are identical focused and
/// unfocused — the whole point. Contrast the pattern it replaces:
///
/// ```dart
/// // Before: focusing shrinks the content box by 2px on every side.
/// AnimatedContainer(
///   decoration: BoxDecoration(
///     border: Border.all(color: focused ? colors.ring : Colors.transparent, width: 2),
///   ),
///   child: content,
/// )
///
/// // After: same pixels, no reflow, and a ring you can actually see.
/// BeuiFocusRing(
///   focused: focused,
///   borderRadius: BorderRadius.circular(12),
///   child: content,
/// )
/// ```
///
/// [color] defaults to [BeuiColors.focusRing], the role sized for this job.
/// Do not pass [BeuiColors.ring] — that is the hairline-border token, and
/// passing it reintroduces the 1.3:1 contrast bug this widget exists to fix.
///
/// The fade is an opacity transition, so reduced motion keeps it (movement is
/// dropped, opacity is not — see [motionFor]). Nothing here moves.
class BeuiFocusRing extends StatelessWidget {
  /// Wraps [child] with a focus ring shown when [focused].
  const BeuiFocusRing({
    required this.focused,
    required this.child,
    this.borderRadius,
    this.width = beuiFocusRingWidth,
    this.color,
    this.offset = 0,
    this.motion = beuiFocusRingMotion,
    super.key,
  });

  /// Whether the ring is shown.
  final bool focused;

  /// The control. Sizes the whole widget; never moved or resized.
  final Widget child;

  /// Ring corner radius. Null draws a rectangle — pass the child's own radius
  /// so the ring stays concentric with it.
  final BorderRadius? borderRadius;

  /// Ring thickness. Defaults to [beuiFocusRingWidth].
  final double width;

  /// Ring color. Defaults to [BeuiColors.focusRing] from the ambient theme.
  final Color? color;

  /// Outward gap between the child's edge and the ring, in logical pixels.
  ///
  /// 0 (the default) draws the ring straddling the edge, matching the source's
  /// inline `ring-2`. A positive value floats the ring outside the child — it
  /// still costs no layout, because the `Stack` does not clip, but the caller
  /// must leave room in the *parent* or the ring will be clipped by an
  /// ancestor's bounds.
  final double offset;

  /// Fade motion. Defaults to [beuiFocusRingMotion].
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    // Same fallback every agent widget uses: the installed palette, or the
    // neutral one at the ambient brightness.
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final ringColor = color ?? colors.focusRing;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -offset,
          top: -offset,
          right: -offset,
          bottom: -offset,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: SingleMotionBuilder(
                value: focused ? 1.0 : 0.0,
                // Opacity, not movement — reduced motion keeps this.
                motion: motionFor(context, motion, isMovement: false),
                builder: (context, t, _) {
                  final opacity = t.clamp(0.0, 1.0);
                  if (opacity <= 0.001) return const SizedBox.shrink();
                  return Opacity(
                    opacity: opacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(color: ringColor, width: width),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
