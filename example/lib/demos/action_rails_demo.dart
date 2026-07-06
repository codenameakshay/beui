import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiExpandableActionBar] + [BeuiOverflowActions] —
/// hover the top rail; tap ⋯ on the bottom one.
Widget actionRailsDemo(BuildContext context) => const _ActionRailsDemo();

class _ActionRailsDemo extends StatefulWidget {
  const _ActionRailsDemo();

  @override
  State<_ActionRailsDemo> createState() => _ActionRailsDemoState();
}

class _ActionRailsDemoState extends State<_ActionRailsDemo> {
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
          ),
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
