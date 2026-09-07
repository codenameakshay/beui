import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'smooth_scroll.dart';

enum _Variant { bar, circle }

/// A scroll progress indicator — bar or circular ring — the Flutter port of
/// beUI's `ScrollProgress`.
///
/// Reads [progress] when given, otherwise the nearest [BeuiSmoothScroll]
/// provider. [spring] smooths the value with the source's soft follow spring;
/// it is disabled automatically under reduced motion (position snaps — the
/// indicator itself is decorative and stays visible).
///
/// Placement is the consumer's: put the bar at the top of a `Stack`, the ring
/// wherever it belongs (source `fixed` has no Flutter analog).
class BeuiScrollProgress extends StatelessWidget {
  /// A thin edge-to-edge bar that scales horizontally with progress
  /// (source `variant: "bar"`).
  const BeuiScrollProgress.bar({
    this.progress,
    this.spring = true,
    this.height = 2,
    super.key,
  }) : _variant = _Variant.bar,
       size = 40,
       thickness = 3;

  /// A circular ring that draws around with progress
  /// (source `variant: "circle"`); painted with `CustomPaint`, not an asset.
  const BeuiScrollProgress.circle({
    this.progress,
    this.spring = true,
    this.size = 40,
    this.thickness = 3,
    super.key,
  }) : _variant = _Variant.circle,
       height = 2;

  final _Variant _variant;

  /// Overrides the scroll source. Defaults to the enclosing
  /// [BeuiSmoothScroll]'s progress.
  final ValueListenable<double>? progress;

  /// Spring-smooth the value (source `spring`, default true).
  final bool spring;

  /// Bar thickness in px (source `height = 2`).
  final double height;

  /// Ring diameter in px (source `size = 40`).
  final double size;

  /// Ring stroke width in px (source `thickness = 3`).
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final source =
        progress ??
        BeuiSmoothScroll.maybeOf(context)?.progress ??
        const AlwaysStoppedAnimation(0.0);

    // aria-hidden: purely decorative.
    return ExcludeSemantics(
      child: ValueListenableBuilder<double>(
        valueListenable: source,
        builder: (context, raw, _) {
          if (!spring || reduce) return _paint(raw, colors);
          return SingleMotionBuilder(
            value: raw,
            motion: beuiSpringScroll,
            builder: (context, smoothed, _) => _paint(smoothed, colors),
          );
        },
      ),
    );
  }

  Widget _paint(double value, BeuiColors colors) {
    switch (_variant) {
      case _Variant.bar:
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Transform(
            alignment: Alignment.centerLeft, // origin-left
            transform: Matrix4.diagonal3Values(value.clamp(0.0, 1.0), 1, 1),
            child: ColoredBox(color: colors.foreground),
          ),
        );
      case _Variant.circle:
        return CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            progress: value.clamp(0.0, 1.0),
            color: colors.foreground,
            thickness: thickness,
          ),
        );
    }
  }
}

/// Track ring at 15% opacity + a round-capped arc from 12 o'clock — the
/// source's dasharray/dashoffset SVG, drawn directly.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.thickness,
  });

  final double progress;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - thickness) / 2;
    final track = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawCircle(center, radius, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // rotate(-90)
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.thickness != thickness;
}
