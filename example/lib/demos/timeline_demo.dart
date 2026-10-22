import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTimeline].
Widget timelineDemo(BuildContext context) => BeuiTimeline(
  events: [
    _event('beta', '2025-06-12', 'Private beta opens', '1,204'),
    _event('android', '2025-08-03', 'Lumen for Android', '3,918'),
    _event('offline', '2025-10-14', 'Offline drafts', '4,827'),
    _event('signups', '2025-11-20', 'Weekly signups double', '6,175'),
    _event('spaces', '2026-01-09', 'Shared spaces', '2,640'),
    _event('command', '2026-03-17', 'The command menu', '5,302'),
    _event('rank', '2026-05-28', 'Top 10 in productivity', '13,916'),
    _event('two', '2026-08-05', 'Lumen 2.0', '27,130'),
  ],
  defaultValue: 'signups',
  semanticLabel: 'Lumen release history',
);

BeuiTimelineEvent _event(String id, String date, String title, String likes) =>
    BeuiTimelineEvent(
      id: id,
      date: date,
      title: title,
      media: CustomPaint(
        painter: _TimelineMediaPainter(id),
        child: const SizedBox.expand(),
      ),
      meta: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border, size: 16),
          const SizedBox(width: 6),
          Text(likes),
        ],
      ),
    );

class _TimelineMediaPainter extends CustomPainter {
  const _TimelineMediaPainter(this.id);

  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    if (id == 'signups') {
      _paintChart(canvas, size);
    } else if (id == 'android' || id == 'rank' || id == 'two') {
      _paintPhotoGrid(canvas, size);
    } else {
      _paintDocument(canvas, size);
    }
  }

  void _paintChart(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff17191d),
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path();
    const points = [
      Offset(0, .72),
      Offset(.12, .65),
      Offset(.23, .7),
      Offset(.34, .48),
      Offset(.46, .54),
      Offset(.58, .39),
      Offset(.69, .43),
      Offset(.81, .2),
      Offset(.91, .27),
      Offset(1, .12),
    ];
    for (var i = 0; i < points.length; i++) {
      final point = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }
    final glow = Paint()
      ..color = const Color(0xffb4f3d0).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(line, glow);
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xffc1f6d7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final end = Offset(size.width, size.height * .12);
    canvas.drawCircle(end, 4, Paint()..color = Colors.white);
    canvas.drawCircle(
      end,
      8,
      Paint()
        ..color = const Color(0xffc1f6d7).withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintDocument(Canvas canvas, Size size) {
    final muted = const Color(0xffd7dde4).withValues(alpha: 0.44);
    final sheet = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .54),
        width: size.width * .61,
        height: size.height * .72,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      sheet,
      Paint()..color = const Color(0xffedf0f2).withValues(alpha: 0.12),
    );
    final left = size.width * .27;
    final top = size.height * .25;
    final rowPaint = Paint()
      ..color = muted
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(left, top),
      Offset(size.width * .64, top),
      rowPaint..strokeWidth = 5,
    );
    for (var i = 1; i <= 4; i++) {
      final y = top + i * size.height * .13;
      canvas.drawCircle(Offset(left, y), 2, Paint()..color = muted);
      canvas.drawLine(
        Offset(left + 12, y),
        Offset(size.width * (.58 + (i.isEven ? .12 : 0)), y),
        rowPaint,
      );
    }
  }

  void _paintPhotoGrid(Canvas canvas, Size size) {
    const shades = [
      Color(0xffc6cfcc),
      Color(0xff9faeaa),
      Color(0xffd5d5ca),
      Color(0xff879791),
      Color(0xffbbc4be),
      Color(0xffa4ada8),
    ];
    final gap = size.width * .025;
    final cellWidth = (size.width * .76 - gap * 2) / 3;
    final cellHeight = size.height * .64;
    final origin = Offset(size.width * .12, size.height * .18);
    for (var i = 0; i < shades.length; i++) {
      final column = i % 3;
      final row = i ~/ 3;
      final rect = Rect.fromLTWH(
        origin.dx + column * (cellWidth + gap),
        origin.dy + row * (cellHeight + gap),
        cellWidth,
        cellHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = shades[i].withValues(alpha: 0.38),
      );
      final sun = Offset(
        rect.left + rect.width * .68,
        rect.top + rect.height * .3,
      );
      canvas.drawCircle(
        sun,
        math.min(rect.width, rect.height) * .1,
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
      final hill = Path()
        ..moveTo(rect.left, rect.bottom * .78)
        ..quadraticBezierTo(
          rect.center.dx,
          rect.top + rect.height * .36,
          rect.right,
          rect.bottom * .73,
        )
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      canvas.drawPath(
        hill,
        Paint()..color = const Color(0xff586a66).withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineMediaPainter oldDelegate) =>
      oldDelegate.id != id;
}
