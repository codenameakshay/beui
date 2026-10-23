import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Ports the source preview's actual SVG and CSS artwork, including its data.
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
      media: _TimelineMedia(id),
      meta: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.heart, size: 16),
          const SizedBox(width: 6),
          Text(likes),
        ],
      ),
    );

class _TimelineMedia extends StatelessWidget {
  const _TimelineMedia(this.id);
  final String id;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    if (id == 'two') {
      return ColoredBox(
        color: colors.foreground,
        child: Center(
          child: Text(
            '2.0',
            style: TextStyle(
              fontSize: 48,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: -2.4,
              color: colors.background,
            ),
          ),
        ),
      );
    }
    if (id == 'command') {
      return ColoredBox(
        color: colors.muted.withValues(alpha: .4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final key in ['⌘', 'K']) ...[
                  if (key == 'K') const SizedBox(width: 6),
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.background,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0d000000),
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      key,
                      style: TextStyle(fontSize: 18, color: colors.foreground),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: 112,
              height: 8,
              decoration: BoxDecoration(
                color: colors.foreground.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      );
    }
    final paint = CustomPaint(
      painter: _TimelineMediaPainter(id, colors),
      child: const SizedBox.expand(),
    );
    return id == 'signups' || id == 'rank'
        ? Semantics(image: true, label: 'Rising line chart', child: paint)
        : paint;
  }
}

class _TimelineMediaPainter extends CustomPainter {
  const _TimelineMediaPainter(this.id, this.colors);
  final String id;
  final BeuiColors colors;

  void _box(
    Canvas canvas,
    Rect rect, {
    double radius = 12,
    double opacity = 1,
  }) {
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      shape,
      Paint()..color = colors.background.withValues(alpha: opacity),
    );
    canvas.drawRRect(
      shape.deflate(.5),
      Paint()
        ..color = colors.border.withValues(alpha: colors.border.a * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _bar(Canvas canvas, Rect rect, double alpha) => canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(99)),
    Paint()..color = colors.foreground.withValues(alpha: alpha),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (id == 'signups' || id == 'rank') {
      _chart(
        canvas,
        size,
        id == 'signups'
            ? const [4, 5, 4, 6, 5, 7, 6, 9, 8, 12, 11, 15]
            : const [3, 4, 6, 5, 8, 9, 8, 11, 13, 12, 14, 16],
      );
      return;
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.muted.withValues(alpha: .4),
    );
    if (id == 'beta' || id == 'spaces') {
      final cellWidth = (size.width - 48) / 3;
      final cellHeight = (size.height - 40) / 2;
      for (var i = 0; i < 6; i++) {
        _box(
          canvas,
          Rect.fromLTWH(
            16 + (i % 3) * (cellWidth + 8),
            16 + (i ~/ 3) * (cellHeight + 8),
            cellWidth,
            cellHeight,
          ),
          opacity: 1 - i * .1,
        );
      }
    } else if (id == 'android') {
      final phone = Rect.fromLTWH(
        size.width / 4,
        20,
        size.width / 2,
        size.height,
      );
      _box(canvas, phone, radius: 24);
      final content = phone.deflate(12);
      _bar(
        canvas,
        Rect.fromLTWH(phone.center.dx - 16, content.top, 32, 6),
        .15,
      );
      _bar(
        canvas,
        Rect.fromLTWH(
          content.left,
          content.top + 14,
          content.width * 2 / 3,
          12,
        ),
        .15,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(content.left, content.top + 34, content.width, 64),
          const Radius.circular(12),
        ),
        Paint()..color = colors.foreground.withValues(alpha: .06),
      );
      _bar(
        canvas,
        Rect.fromLTWH(content.left, content.top + 106, content.width, 8),
        .1,
      );
      _bar(
        canvas,
        Rect.fromLTWH(content.left, content.top + 122, content.width * .8, 8),
        .1,
      );
    } else if (id == 'offline') {
      final area = (Offset.zero & size).deflate(20);
      final secondary = Rect.fromLTWH(
        area.right - area.width / 4,
        area.top + area.height * .1,
        area.width / 4,
        area.height * .8,
      );
      final main = Rect.fromLTRB(
        area.left,
        area.top,
        secondary.left - 12,
        area.bottom,
      );
      _box(canvas, main);
      _box(canvas, secondary, radius: 16);
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(main.left + 15 + i * 10, main.top + 15),
          3,
          Paint()..color = colors.foreground.withValues(alpha: .2),
        );
      }
      for (final (box, padding, top) in [
        (main, 12.0, 26.0),
        (secondary, 8.0, 8.0),
      ]) {
        for (var i = 0; i < 3; i++) {
          _bar(
            canvas,
            Rect.fromLTWH(
              box.left + padding,
              box.top + top + i * 16,
              (box.width - padding * 2) * [0.75, 1.0, 2 / 3][i],
              8,
            ),
            i == 0 ? .15 : .1,
          );
        }
      }
    }
  }

  void _chart(Canvas canvas, Size size, List<int> points) {
    final maximum = points.reduce(math.max);
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i / (points.length - 1) * size.width;
      final y = (56 - points[i] / maximum * 44) / 64 * size.height;
      i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = colors.foreground.withValues(alpha: .06),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_TimelineMediaPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.colors != colors;
}
