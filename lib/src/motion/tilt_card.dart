import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// A card that tilts in 3D toward the cursor with a following glare — the
/// Flutter port of beUI's `tilt-card`.
///
/// Tracking the pointer over the card sets a target rotation
/// (`rotateX = (0.5 - py)·max`, `rotateY = (px - 0.5)·max`) that is spring-
/// smoothed with [beuiSpringMouse]; the edge under the cursor recedes, as in
/// the source. A soft radial [glare] follows the cursor. Hover-only (built on
/// `MouseRegion`, so it never reacts to touch); reduced motion drops the tilt
/// and glare entirely.
class BeuiTiltCard extends StatefulWidget {
  /// Creates a tilt card around [child] (which defines the card's size).
  const BeuiTiltCard({
    required this.child,
    this.max = 12,
    this.glare = true,
    this.glareColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    super.key,
  });

  /// The card content; its intrinsic size is the card's size.
  final Widget child;

  /// Maximum tilt, in degrees.
  final double max;

  /// Whether to render the cursor-following glare.
  final bool glare;

  /// Glare colour. Defaults to `BeuiColors.foreground`.
  final Color? glareColor;

  /// Corner radius (clips the card and glare). `rounded-2xl` by default.
  final BorderRadius borderRadius;

  @override
  State<BeuiTiltCard> createState() => _BeuiTiltCardState();
}

class _BeuiTiltCardState extends State<BeuiTiltCard> {
  final GlobalKey _key = GlobalKey();
  double _rx = 0; // target rotateX (radians)
  double _ry = 0; // target rotateY (radians)
  double _gx = 0.5; // glare x (0..1)
  double _gy = 0.5; // glare y (0..1)
  bool _hovering = false;

  void _onHover(PointerHoverEvent e) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (size.width == 0 || size.height == 0) return;
    final px = (e.localPosition.dx / size.width).clamp(0.0, 1.0);
    final py = (e.localPosition.dy / size.height).clamp(0.0, 1.0);
    final maxRad = widget.max * math.pi / 180;
    setState(() {
      _rx = (0.5 - py) * maxRad;
      _ry = (px - 0.5) * maxRad;
      _gx = px;
      _gy = py;
      _hovering = true;
    });
  }

  void _onExit(PointerExitEvent e) {
    setState(() {
      _rx = 0;
      _ry = 0;
      _hovering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final glareColor = widget.glareColor ?? colors.foreground;

    final content = ClipRRect(
      key: _key,
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          widget.child,
          if (widget.glare && !reduce)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _hovering ? 0.15 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(_gx * 2 - 1, _gy * 2 - 1),
                        radius: 0.7,
                        colors: [glareColor, glareColor.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (reduce) return content;

    return MouseRegion(
      onHover: _onHover,
      onExit: _onExit,
      child: MotionBuilder<Offset>(
        value: Offset(_rx, _ry),
        motion: beuiSpringMouse,
        converter: const OffsetMotionConverter(),
        child: content,
        builder: (context, rot, child) {
          // Flutter's perspective z runs into the screen (opposite of CSS), so
          // the rotation signs flip to keep the source's "edge under the cursor
          // recedes" tilt.
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective(1000px)
            ..rotateX(-rot.dx)
            ..rotateY(-rot.dy);
          return Transform(
            transform: m,
            alignment: Alignment.center,
            child: child,
          );
        },
      ),
    );
  }
}
