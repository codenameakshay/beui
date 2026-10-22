import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTimeline].
Widget timelineDemo(BuildContext context) => BeuiTimeline(
  events: [
    _event(
      'beta',
      '2025-06-12',
      'Private beta opens',
      const Color(0xffd9e7ff),
      '1,204',
    ),
    _event(
      'android',
      '2025-08-03',
      'Lumen for Android',
      const Color(0xffdff4e6),
      '3,918',
    ),
    _event(
      'offline',
      '2025-10-14',
      'Offline drafts',
      const Color(0xffffedcf),
      '4,827',
    ),
    _event(
      'signups',
      '2025-11-20',
      'Weekly signups double',
      const Color(0xffffe1e4),
      '6,175',
    ),
    _event(
      'spaces',
      '2026-01-09',
      'Shared spaces',
      const Color(0xffe9e0ff),
      '2,640',
    ),
    _event(
      'command',
      '2026-03-17',
      'The command menu',
      const Color(0xffd9f2f2),
      '5,302',
    ),
    _event(
      'rank',
      '2026-05-28',
      'Top 10 in productivity',
      const Color(0xffffe8d7),
      '13,916',
    ),
    _event(
      'two',
      '2026-08-05',
      'Lumen 2.0',
      const Color(0xff242424),
      '27,130',
      darkText: true,
    ),
  ],
  defaultValue: 'signups',
  semanticLabel: 'Lumen release history',
);

BeuiTimelineEvent _event(
  String id,
  String date,
  String title,
  Color color,
  String likes, {
  bool darkText = false,
}) => BeuiTimelineEvent(
  id: id,
  date: date,
  title: title,
  media: ColoredBox(
    color: color,
    child: Center(
      child: Text(
        id == 'two' ? '2.0' : title.split(' ').first,
        style: TextStyle(
          color: darkText ? Colors.white : const Color(0xff343434),
          fontSize: id == 'two' ? 42 : 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
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
