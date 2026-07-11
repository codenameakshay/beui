import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiExpandableTabs] — tap an icon to bloom its panel.
Widget expandableTabsDemo(BuildContext context) => const _ExpandableTabsDemo();

class _ExpandableTabsDemo extends StatelessWidget {
  const _ExpandableTabsDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    Widget panel(String title, List<String> rows) => SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.mutedForeground,
              ),
            ),
          ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                row,
                style: TextStyle(fontSize: 14, color: colors.foreground),
              ),
            ),
        ],
      ),
    );

    return Center(
      child: BeuiExpandableTabs(
        items: [
          BeuiExpandableTabsItem(
            id: 'home',
            label: 'Home',
            icon: LucideIcons.house,
            content: panel('HOME', ['Dashboard', 'Recent activity', 'Pinned']),
          ),
          BeuiExpandableTabsItem(
            id: 'search',
            label: 'Search',
            icon: LucideIcons.search,
            content: panel('SEARCH', ['Files', 'Commands', 'People']),
          ),
          BeuiExpandableTabsItem(
            id: 'alerts',
            label: 'Alerts',
            icon: LucideIcons.bell,
            content: panel('ALERTS', [
              '2 review requests',
              'Deploy finished',
              'New follower',
            ]),
          ),
          BeuiExpandableTabsItem(
            id: 'profile',
            label: 'Profile',
            icon: LucideIcons.user,
            content: panel('PROFILE', ['Settings', 'Appearance', 'Sign out']),
          ),
        ],
      ),
    );
  }
}
