/// The streaming/done status glyph shared by [code_block.dart] and
/// [file_diff.dart].
library;

import 'package:flutter/widgets.dart';

/// A status icon that spins on [spin] while [streaming] is true, and holds
/// still (as a plain [Icon]) once done or under reduced motion.
class BeuiStreamingStatusIcon extends StatelessWidget {
  /// Creates a streaming status icon.
  const BeuiStreamingStatusIcon({
    required this.icon,
    required this.streaming,
    required this.reduce,
    required this.color,
    required this.spin,
    this.size = 14,
    this.semanticLabel,
    super.key,
  });

  /// Glyph to paint (typically a loader while streaming, a checkmark once
  /// done).
  final IconData icon;

  /// Whether the glyph should keep spinning.
  final bool streaming;

  /// Drops the rotation under reduced motion.
  final bool reduce;

  /// Glyph color.
  final Color color;

  /// Rotation driver, owned by the caller.
  final AnimationController spin;

  /// Glyph size in logical pixels.
  final double size;

  /// Optional accessible label for the glyph.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
    if (!streaming || reduce) return iconWidget;
    return RotationTransition(turns: spin, child: iconWidget);
  }
}
