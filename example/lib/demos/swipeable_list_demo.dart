import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiSwipeableList] — drag rows sideways.
Widget swipeableListDemo(BuildContext context) => const _SwipeableListDemo();

class _SwipeableListDemo extends StatefulWidget {
  const _SwipeableListDemo();

  @override
  State<_SwipeableListDemo> createState() => _SwipeableListDemoState();
}

class _SwipeableListDemoState extends State<_SwipeableListDemo> {
  String _last = '—';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    BeuiSwipeAction action(
      String id,
      String label,
      IconData icon, [
      BeuiSwipeActionTone tone = BeuiSwipeActionTone.neutral,
    ]) => BeuiSwipeAction(id: id, label: label, icon: icon, tone: tone);

    Widget avatar(IconData icon, Color color) => CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, size: 16, color: color),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiSwipeableList(
              onAction: (item, act, side) =>
                  setState(() => _last = '${act.label} → ${item.title}'),
              items: [
                BeuiSwipeableListItem(
                  id: 'review',
                  title: 'Design review',
                  description: 'Nia updated the Figma file',
                  meta: '2m',
                  leading: avatar(LucideIcons.pen_tool, colors.primary),
                  leftActions: [
                    action(
                      'pin',
                      'Pin',
                      LucideIcons.pin,
                      BeuiSwipeActionTone.primary,
                    ),
                  ],
                  rightActions: [
                    action('archive', 'Archive', LucideIcons.archive),
                    action(
                      'delete',
                      'Delete',
                      LucideIcons.trash_2,
                      BeuiSwipeActionTone.danger,
                    ),
                  ],
                ),
                BeuiSwipeableListItem(
                  id: 'deploy',
                  title: 'Deploy finished',
                  description: 'production · v2.14.0 · 41s',
                  meta: '9m',
                  leading: avatar(LucideIcons.rocket, const Color(0xFF059669)),
                  rightActions: [
                    action(
                      'done',
                      'Mark done',
                      LucideIcons.check,
                      BeuiSwipeActionTone.success,
                    ),
                    action('mute', 'Mute', LucideIcons.bell_off),
                  ],
                ),
                BeuiSwipeableListItem(
                  id: 'invoice',
                  title: 'Invoice overdue',
                  description: 'ACME Corp · \$2,300',
                  meta: '1h',
                  leading: avatar(LucideIcons.receipt, const Color(0xFFD97706)),
                  leftActions: [
                    action(
                      'remind',
                      'Remind',
                      LucideIcons.bell,
                      BeuiSwipeActionTone.warning,
                    ),
                  ],
                  rightActions: [
                    action(
                      'pay',
                      'Pay now',
                      LucideIcons.credit_card,
                      BeuiSwipeActionTone.primary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Last action: $_last',
              style: TextStyle(color: colors.mutedForeground, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
