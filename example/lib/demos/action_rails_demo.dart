import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiExpandableActionBar] — mirrors
/// `expandable-action-bar.preview.tsx`.
Widget expandableActionBarDemo(BuildContext context) =>
    const _ExpandableActionBarDemo();

/// Gallery route for [BeuiOverflowActions] — mirrors
/// `overflow-actions.preview.tsx`.
Widget overflowActionsDemo(BuildContext context) => const Center(
  child: BeuiOverflowActions(
    primaryActions: [
      BeuiOverflowActionItem(
        id: 'preview',
        label: 'Preview',
        icon: LucideIcons.eye,
      ),
      BeuiOverflowActionItem(id: 'pin', label: 'Pin', icon: LucideIcons.pin),
    ],
    overflowActions: [
      BeuiOverflowActionItem(
        id: 'branch',
        label: 'Branch',
        icon: LucideIcons.git_branch,
      ),
      BeuiOverflowActionItem(
        id: 'schedule',
        label: 'Schedule',
        icon: LucideIcons.calendar_clock,
      ),
    ],
    openLabel: 'Open action rail',
    closeLabel: 'Collapse action rail',
  ),
);

class _ExpandableActionBarDemo extends StatefulWidget {
  const _ExpandableActionBarDemo();

  @override
  State<_ExpandableActionBarDemo> createState() =>
      _ExpandableActionBarDemoState();
}

class _ExpandableActionBarDemoState extends State<_ExpandableActionBarDemo> {
  bool _expanded = false;
  String _activeId = 'send';

  static const _actions = [
    BeuiExpandableActionBarItem(
      id: 'send',
      label: 'Send',
      icon: LucideIcons.send,
      shortcut: 'S',
    ),
    BeuiExpandableActionBarItem(
      id: 'copy',
      label: 'Copy',
      icon: LucideIcons.copy,
      shortcut: 'C',
    ),
    BeuiExpandableActionBarItem(
      id: 'download',
      label: 'Export',
      icon: LucideIcons.download,
      shortcut: 'E',
    ),
    BeuiExpandableActionBarItem(
      id: 'archive',
      label: 'Archive',
      icon: LucideIcons.archive,
    ),
    BeuiExpandableActionBarItem(
      id: 'alerts',
      label: 'Alerts',
      icon: LucideIcons.bell,
      badge: Text('3'),
    ),
    BeuiExpandableActionBarItem(
      id: 'settings',
      label: 'Settings',
      icon: LucideIcons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      // `min-h-72 flex-col items-center justify-center gap-6`.
      constraints: const BoxConstraints(minHeight: 288),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        spacing: 24, // gap-6
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96), // min-h-24
            child: Center(
              child: BeuiExpandableActionBar(
                items: _actions,
                expanded: _expanded,
                onExpandedChange: (v) => setState(() => _expanded = v),
                activeId: _activeId,
                onAction: (item) => setState(() => _activeId = item.id),
              ),
            ),
          ),
          _ExpandToggle(
            expanded: _expanded,
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
    ),
  );
}

/// The preview's own Expand/Collapse toggle: `h-9 w-[110px] rounded-full
/// border bg-card text-xs`, with a maximize/minimize glyph.
class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 36, // h-9
          width: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6, // gap-1.5
            children: [
              Icon(
                expanded ? LucideIcons.minimize_2 : LucideIcons.maximize_2,
                size: 14,
                color: colors.foreground,
              ),
              Text(
                expanded ? 'Collapse' : 'Expand',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
