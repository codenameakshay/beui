import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

Widget morphingTabsDemo(BuildContext context) => const _MorphingTabsDemo();

const _rooms = <String, ({String eyebrow, String title, String detail, Color accent})>{
  'room-2': (
    eyebrow: 'quiet focus',
    title: 'Room 2',
    detail:
        'A small space for the work that needs a little more air around it.',
    accent: Color(0xffdb5b2f),
  ),
  'general': (
    eyebrow: 'shared space',
    title: 'General',
    detail:
        'The common room for notes, links and the ideas that are still finding their shape.',
    accent: Color(0xff1bb273),
  ),
  'archive': (
    eyebrow: 'kept close',
    title: 'Archive',
    detail:
        'Past rooms stay available without competing with the conversations in motion.',
    accent: Color(0xff7a6de2),
  ),
};

class _MorphingTabsDemo extends StatefulWidget {
  const _MorphingTabsDemo();

  @override
  State<_MorphingTabsDemo> createState() => _MorphingTabsDemoState();
}

class _MorphingTabsDemoState extends State<_MorphingTabsDemo> {
  late List<String> _order = _rooms.keys.toList();
  String? _value = 'room-2';

  @override
  Widget build(BuildContext context) {
    final items = _order.where(_rooms.containsKey).map((id) {
      final room = _rooms[id]!;
      return BeuiMorphingTabsItem(
        id: id,
        label: room.title,
        content: _RoomPanel(room: room),
      );
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: const Color(0xff242424),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1024),
        child: BeuiMorphingTabs(
          items: items,
          value: _value,
          semanticLabel: 'Rooms',
          onValueChange: (value) => setState(() => _value = value),
          onOrderChange: (order) => setState(() => _order = order),
          onClose: (id) {
            setState(() {
              _order = _order.where((item) => item != id).toList();
              if (_value == id) _value = _order.firstOrNull;
            });
          },
        ),
      ),
    );
  }
}

class _RoomPanel extends StatelessWidget {
  const _RoomPanel({required this.room});

  final ({String eyebrow, String title, String detail, Color accent}) room;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _DotGridPainter(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 176, maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.eyebrow.toUpperCase(),
              style: const TextStyle(
                color: Color(0x66000000),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              room.title,
              style: const TextStyle(
                color: Color(0xff151515),
                fontSize: 42,
                fontWeight: FontWeight.w300,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              room.detail,
              style: const TextStyle(
                color: Color(0x8c000000),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: room.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 8, height: 8),
                ),
                const SizedBox(width: 12),
                const Text(
                  'drag any room to reorder',
                  style: TextStyle(
                    color: Color(0x80000000),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xffdfe2e3);
    for (double x = 1; x < size.width; x += 77) {
      for (double y = 1; y < size.height; y += 77) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}
