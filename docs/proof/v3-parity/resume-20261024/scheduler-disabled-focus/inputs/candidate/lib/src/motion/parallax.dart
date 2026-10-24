import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '_engine.dart';
import '_scroll_geometry.dart';

/// Axis the parallax drift moves along.
enum BeuiParallaxAxis {
  /// Horizontal drift.
  x,

  /// Vertical drift (default).
  y,
}

/// Drifts its child against the scroll as it crosses the viewport — the
/// Flutter port of beUI's `Parallax`.
///
/// Progress runs 0→1 as the element travels through the nearest enclosing
/// scrollable's viewport (source `offset: ["start end", "end start"]`); the
/// drift maps symmetrically from `+speed*100` px to `-speed*100` px. Positive
/// [speed] moves with the scroll (foreground), negative against it
/// (background); ~0.1–0.5 reads best.
///
/// Reduced motion renders the child static — the effect is disabled by the
/// component, per the motion rules.
class BeuiParallax extends StatefulWidget {
  /// Creates a parallax drift wrapper.
  const BeuiParallax({
    required this.child,
    this.speed = 0.3,
    this.axis = BeuiParallaxAxis.y,
    this.spring = true,
    super.key,
  });

  /// The drifting content.
  final Widget child;

  /// Drift as a fraction of the element's viewport travel (source
  /// `speed = 0.3`).
  final double speed;

  /// Drift axis (source `axis = "y"`). The scroll itself is vertical.
  final BeuiParallaxAxis axis;

  /// Spring-smooth the drift (source `spring = true`).
  final bool spring;

  @override
  State<BeuiParallax> createState() => _BeuiParallaxState();
}

class _BeuiParallaxState extends State<BeuiParallax> with ScrollGeometryMixin {
  double _drift = 0;

  @override
  void onScrollGeometryChanged() {
    final progress = crossingProgress;
    if (progress == null) return;
    final travel = widget.speed * 100;
    final drift = travel - 2 * travel * progress; // lerp(travel, -travel, p)
    if (drift != _drift) setState(() => _drift = drift);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) return widget.child;

    Widget at(double value) => Transform.translate(
      offset: widget.axis == BeuiParallaxAxis.x
          ? Offset(value, 0)
          : Offset(0, value),
      child: widget.child,
    );

    if (!widget.spring) return at(_drift);
    return SingleMotionBuilder(
      value: _drift,
      motion: beuiSpringScroll,
      builder: (context, value, _) => at(value),
    );
  }
}
