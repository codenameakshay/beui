/// The indeterminate ring spinner shared by the badge, toast, and button.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A 3/4 arc (Lucide's `loader-circle`) painted with a stroke of 12% of
/// [size], spinning once per second.
///
/// Drawn with a [CustomPainter] rather than rotating a font glyph: a rotated
/// glyph wobbles because its visual centre is not the em-box centre.
class BeuiSpinner extends StatefulWidget {
  /// Creates the spinner.
  const BeuiSpinner({required this.size, required this.color, super.key});

  /// Diameter in logical pixels.
  final double size;

  /// Stroke color.
  final Color color;

  @override
  State<BeuiSpinner> createState() => _BeuiSpinnerState();
}

class _BeuiSpinnerState extends State<BeuiSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _ArcPainter(color: widget.color, stroke: widget.size * 0.12),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.color != color || old.stroke != stroke;
}
