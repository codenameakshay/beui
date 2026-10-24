import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Filled 14px marks from the pinned source search preview, not favicons.
class AgentSearchMark extends StatelessWidget {
  const AgentSearchMark(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(14),
    painter: _SearchMarkPainter(
      name,
      BeuiColors.resolve(context).mutedForeground,
    ),
  );
}

class _SearchMarkPainter extends CustomPainter {
  const _SearchMarkPainter(this.name, this.color);
  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    switch (name) {
      case 'google':
        canvas.drawPath(
          Path()
            ..moveTo(21.35, 12.23)
            ..cubicTo(21.35, 11.58, 21.29, 10.95, 21.18, 10.34)
            ..lineTo(12, 10.34)
            ..lineTo(12, 14.13)
            ..lineTo(17.25, 14.13)
            ..arcToPoint(
              const Offset(15.3, 17),
              radius: const Radius.elliptical(4.5, 4.5),
              rotation: 0,
              largeArc: false,
              clockwise: true,
            )
            ..lineTo(15.3, 19.46)
            ..lineTo(18.46, 19.46)
            ..cubicTo(20.31, 17.75, 21.35, 15.24, 21.35, 12.23)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 21.75)
            ..cubicTo(14.64, 21.75, 16.86, 20.88, 18.46, 19.46)
            ..lineTo(15.3, 17)
            ..cubicTo(14.43, 17.58, 13.32, 17.92, 12, 17.92)
            ..arcToPoint(
              const Offset(6.65, 13.99),
              radius: const Radius.elliptical(5.7, 5.7),
              rotation: 0,
              largeArc: false,
              clockwise: true,
            )
            ..lineTo(3.39, 13.99)
            ..lineTo(3.39, 16.53)
            ..arcToPoint(
              const Offset(12, 21.75),
              radius: const Radius.elliptical(9.75, 9.75),
              rotation: 0,
              largeArc: false,
              clockwise: false,
            )
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6.65, 13.99)
            ..arcToPoint(
              const Offset(6.34, 12),
              radius: const Radius.elliptical(5.85, 5.85),
              rotation: 0,
              largeArc: false,
              clockwise: true,
            )
            ..cubicTo(6.34, 11.31, 6.46, 10.64, 6.65, 10.01)
            ..lineTo(6.65, 7.47)
            ..lineTo(3.39, 7.47)
            ..arcToPoint(
              const Offset(2.25, 12),
              radius: const Radius.elliptical(9.76, 9.76),
              rotation: 0,
              largeArc: false,
              clockwise: false,
            )
            ..cubicTo(2.25, 13.63, 2.64, 15.18, 3.39, 16.53)
            ..lineTo(6.65, 13.99)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 6.08)
            ..cubicTo(13.44, 6.08, 14.73, 6.57, 15.75, 7.55)
            ..lineTo(18.53, 4.77)
            ..arcToPoint(
              const Offset(12, 2.25),
              radius: const Radius.elliptical(9.34, 9.34),
              rotation: 0,
              largeArc: false,
              clockwise: false,
            )
            ..arcToPoint(
              const Offset(3.39, 7.47),
              radius: const Radius.elliptical(9.75, 9.75),
              rotation: 0,
              largeArc: false,
              clockwise: false,
            )
            ..lineTo(6.65, 10.01)
            ..arcToPoint(
              const Offset(12, 6.08),
              radius: const Radius.elliptical(5.7, 5.7),
              rotation: 0,
              largeArc: false,
              clockwise: true,
            )
            ..close(),
          paint,
        );
      case 'github':
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..arcToPoint(
              const Offset(8.84, 21.49),
              radius: const Radius.elliptical(10, 10),
              rotation: 0,
              largeArc: false,
              clockwise: false,
            )
            ..cubicTo(9.34, 21.58, 9.52, 21.27, 9.52, 21.01)
            ..lineTo(9.52, 19.14)
            ..cubicTo(6.74, 19.74, 6.15, 17.96, 6.15, 17.96)
            ..cubicTo(5.7, 16.8, 5.04, 16.49, 5.04, 16.49)
            ..cubicTo(4.13, 15.87, 5.11, 15.88, 5.11, 15.88)
            ..cubicTo(6.11, 15.95, 6.64, 16.91, 6.64, 16.91)
            ..cubicTo(7.54, 18.44, 8.99, 18, 9.56, 17.74)
            ..cubicTo(9.65, 17.09, 9.91, 16.65, 10.2, 16.4)
            ..cubicTo(7.98, 16.15, 5.65, 15.29, 5.65, 11.46)
            ..cubicTo(5.65, 10.37, 6.04, 9.48, 6.68, 8.78)
            ..cubicTo(6.58, 8.53, 6.23, 7.51, 6.78, 6.14)
            ..cubicTo(6.78, 6.14, 7.62, 5.87, 9.53, 7.16)
            ..arcToPoint(
              const Offset(12, 6.82),
              radius: const Radius.elliptical(9.58, 9.58),
              rotation: 0,
              largeArc: false,
              clockwise: true,
            )
            ..cubicTo(12.85, 6.82, 13.71, 6.93, 14.51, 7.16)
            ..cubicTo(16.42, 5.87, 17.26, 6.14, 17.26, 6.14)
            ..cubicTo(17.81, 7.51, 17.46, 8.53, 17.36, 8.78)
            ..cubicTo(18, 9.48, 18.39, 10.37, 18.39, 11.46)
            ..cubicTo(18.39, 15.3, 16.05, 16.14, 13.82, 16.39)
            ..cubicTo(14.18, 16.7, 14.5, 17.31, 14.5, 18.24)
            ..lineTo(14.5, 21.01)
            ..cubicTo(14.5, 21.28, 14.68, 21.59, 15.19, 21.49)
            ..arcToPoint(
              const Offset(12, 2),
              radius: const Radius.elliptical(10, 10),
              rotation: 0,
              largeArc: false,
              clockwise: false,
            )
            ..close(),
          paint,
        );
      case 'wikipedia':
        canvas.drawPath(
          Path()
            ..moveTo(1.5, 4)
            ..lineTo(7.5, 4)
            ..lineTo(7.5, 5.2)
            ..lineTo(6, 5.2)
            ..lineTo(10.08, 15.93)
            ..lineTo(11.34, 12.81)
            ..lineTo(8.45, 5.2)
            ..lineTo(7.2, 5.2)
            ..lineTo(7.2, 4)
            ..lineTo(13.2, 4)
            ..lineTo(13.2, 5.2)
            ..lineTo(11.73, 5.2)
            ..lineTo(13.39, 9.77)
            ..lineTo(15.21, 5.2)
            ..lineTo(13.8, 5.2)
            ..lineTo(13.8, 4)
            ..lineTo(18.7, 4)
            ..lineTo(18.7, 5.2)
            ..lineTo(17.25, 5.2)
            ..lineTo(14.06, 13.12)
            ..lineTo(15.14, 15.93)
            ..lineTo(19.48, 5.2)
            ..lineTo(18, 5.2)
            ..lineTo(18, 4)
            ..lineTo(22.5, 4)
            ..lineTo(22.5, 5.2)
            ..lineTo(21.08, 5.2)
            ..lineTo(15.25, 20)
            ..lineTo(14.05, 20)
            ..lineTo(12.14, 15.14)
            ..lineTo(10.18, 20)
            ..lineTo(8.92, 20)
            ..lineTo(3.25, 5.2)
            ..lineTo(1.5, 5.2)
            ..lineTo(1.5, 4)
            ..close(),
          paint,
        );
      case 'vercel':
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(22, 21)
            ..lineTo(2, 21)
            ..lineTo(12, 3)
            ..close(),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_SearchMarkPainter old) =>
      name != old.name || color != old.color;
}
