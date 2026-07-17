import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiNotificationStack] — a collapsible stacked-inbox card
/// that fans open on hover/focus/tap and rolls its footer label.
Widget notificationStackDemo(BuildContext context) =>
    const _NotificationStackDemo();

class _NotificationStackDemo extends StatefulWidget {
  const _NotificationStackDemo();

  @override
  State<_NotificationStackDemo> createState() => _NotificationStackDemoState();
}

class _NotificationStackDemoState extends State<_NotificationStackDemo> {
  bool _empty = false;
  String _last = '—';

  static const _items = <BeuiNotificationStackItem>[
    BeuiNotificationStackItem(
      id: 'mention',
      title: 'Aditi mentioned you',
      description: 'in "Motion fidelity — spring tokens"',
    ),
    BeuiNotificationStackItem(
      id: 'review',
      title: 'Review requested',
      description: 'feat: port notification-stack (#42)',
    ),
    BeuiNotificationStackItem(
      id: 'deploy',
      title: 'Preview deployed',
      description: 'beui-gallery · 2m ago',
    ),
    BeuiNotificationStackItem(
      id: 'star',
      title: 'New star on beui',
      description: 'You reached 1,200 stars',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          BeuiNotificationStack(
            items: _empty ? const [] : _items,
            onViewAll: () => setState(() => _last = 'View all'),
          ),
          const SizedBox(height: 220), // room for the fan-out
          BeuiButton(
            variant: BeuiButtonVariant.secondary,
            size: BeuiButtonSize.sm,
            onPressed: () => setState(() => _empty = !_empty),
            child: Text(_empty ? 'Show notifications' : 'Empty state'),
          ),
          const SizedBox(height: 12),
          Text(
            'Last action: $_last',
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
