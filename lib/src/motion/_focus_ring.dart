/// Focus-ring helper — paints a visible focus indicator without moving the
/// thing it is indicating.
///
/// Package-internal. Not exported from `lib/beui.dart`.
///
/// A focus ring drawn as a `BoxDecoration` border insets the child by its own
/// width, turning "focus indicator" into layout jitter. This paints the ring
/// in the foreground, outside layout, in the dedicated [BeuiColors.focusRing]
/// role — a token with the contrast a focus indicator needs, distinct from
/// the hairline [BeuiColors.ring] border token.
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

  @override
  Widget build(BuildContext context) {
    // Same fallback every agent widget uses: the installed palette, or the
    // neutral one at the ambient brightness.
    final colors = BeuiColors.resolve(context);
    final ringColor = color ?? colors.focusRing;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: SingleMotionBuilder(
                value: focused ? 1.0 : 0.0,
                // Opacity, not movement — reduced motion keeps this.
                motion: motionFor(
                  context,
                  beuiFocusRingMotion,
                  isMovement: false,
                ),
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
