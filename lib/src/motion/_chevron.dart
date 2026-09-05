/// The disclosure chevron shared by the agent surfaces.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/beui_agent_theme.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// A chevron that rotates 180° on [beuiSpringSwap] when [open] flips, and
/// snaps between the two poses under reduced motion.
///
/// Reads its glyph from [BeuiAgentIcons.expand] so a themed icon set reaches
/// every disclosure in the library.
class BeuiDisclosureChevron extends StatelessWidget {
  /// Creates the chevron.
  const BeuiDisclosureChevron({
    required this.open,
    required this.color,
    this.size = 14,
    this.reduce,
    super.key,
  });

  /// Whether the disclosure is open (chevron points up).
  final bool open;

  /// Glyph color.
  final Color color;

  /// Glyph size in logical pixels.
  final double size;

  /// Forces the reduced-motion path. Defaults to the ambient
  /// `MediaQuery.disableAnimationsOf`.
  final bool? reduce;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      BeuiAgentTheme.of(context).icons.expand,
      size: size,
      color: color,
    );
    if (reduce ?? MediaQuery.disableAnimationsOf(context)) {
      return Transform.rotate(angle: open ? math.pi : 0, child: icon);
    }
    return SingleMotionBuilder(
      value: open ? 180.0 : 0.0,
      motion: motionFor(context, beuiSpringSwap, isMovement: true),
      builder: (context, deg, child) =>
          Transform.rotate(angle: deg * math.pi / 180.0, child: child),
      child: icon,
    );
  }
}
