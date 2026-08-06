import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiNotificationStack] — mirrors
/// `notification-stack.preview.tsx`: three incident cards, the first carrying
/// an amber retry-count trailing slot.
Widget notificationStackDemo(BuildContext context) =>
    const _NotificationStackDemo();

/// `text-amber-400` — the dark-mode tone the source preview uses for the
/// retry counter.
const _amber400 = Color(0xFFFBBF24);

class _NotificationStackDemo extends StatelessWidget {
  const _NotificationStackDemo();

  @override
  Widget build(BuildContext context) => Padding(
    // Source wrapper is `pt-52 pb-6`: headroom for the upward fan-out.
    padding: const EdgeInsets.only(top: 208, bottom: 24),
    child: Align(
      alignment: Alignment.topCenter,
      child: BeuiNotificationStack(
        items: const [
          BeuiNotificationStackItem(
            id: 'import-failed',
            title: 'Orders import failed',
            description: '42s · TimeoutError at Step 2',
            trailing: _RetryCount(count: 2),
          ),
          BeuiNotificationStackItem(
            id: 'sla-breach',
            title: 'SLA breach',
            description: '2m 11s · Data enrichment',
          ),
          BeuiNotificationStackItem(
            id: 'sync-fixed',
            title: 'Product sync auto-fixed',
            description: '5m · 404 on GET /products',
          ),
        ],
      ),
    ),
  );
}

class _RetryCount extends StatelessWidget {
  const _RetryCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: const TextStyle(color: _amber400),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4, // gap-1
      children: [
        const Icon(LucideIcons.rotate_cw, size: 14, color: _amber400),
        Text('$count'),
      ],
    ),
  );
}
