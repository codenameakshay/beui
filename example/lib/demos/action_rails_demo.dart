import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiExpandableActionBar] — hover a segment to expand it.
Widget expandableActionBarDemo(BuildContext context) =>
    const _RailDemo(overflow: false);

/// Gallery route for [BeuiOverflowActions] — tap ⋯ to fan out the overflow.
Widget overflowActionsDemo(BuildContext context) =>
    const _RailDemo(overflow: true);

class _RailDemo extends StatefulWidget {
  const _RailDemo({required this.overflow});
  final bool overflow;

  @override
  State<_RailDemo> createState() => _RailDemoState();
}

class _RailDemoState extends State<_RailDemo> {
  String _last = '—';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    void run(String id) => setState(() => _last = id);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 40,
        children: [
          if (!widget.overflow)
            BeuiExpandableActionBar(
              onAction: (item) => run(item.id),
              items: const [
                BeuiExpandableActionBarItem(
                  id: 'inbox',
                  label: 'Inbox',
                  icon: LucideIcons.inbox,
                  badge: Text('3'),
                ),
                BeuiExpandableActionBarItem(
                  id: 'send',
                  label: 'Send',
                  icon: LucideIcons.send,
                  shortcut: '⌘↵',
                ),
                BeuiExpandableActionBarItem(
                  id: 'archive',
                  label: 'Archive',
                  icon: LucideIcons.archive,
                  active: true,
                ),
                BeuiExpandableActionBarItem(
                  id: 'trash',
                  label: 'Delete',
                  icon: LucideIcons.trash_2,
                ),
              ],
            )
          else
            BeuiOverflowActions(
              onAction: (item) => run(item.id),
              collapseOnAction: true,
              primaryActions: const [
                BeuiOverflowActionItem(
                  id: 'reply',
                  label: 'Reply',
                  icon: LucideIcons.reply,
                ),
                BeuiOverflowActionItem(
                  id: 'forward',
                  label: 'Forward',
                  icon: LucideIcons.forward,
                ),
              ],
              overflowActions: const [
                BeuiOverflowActionItem(
                  id: 'archive',
                  label: 'Archive',
                  icon: LucideIcons.archive,
                ),
                BeuiOverflowActionItem(
                  id: 'mute',
                  label: 'Mute',
                  icon: LucideIcons.bell_off,
                ),
                BeuiOverflowActionItem(
                  id: 'delete',
                  label: 'Delete',
                  icon: LucideIcons.trash_2,
                ),
              ],
            ),
          Text(
            'Last action: $_last',
            style: TextStyle(color: colors.mutedForeground, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
