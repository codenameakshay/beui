import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiAnimatedSidebar] — matches the source preview:
/// a Solace-style workspace shell with quick links, nested Workspaces group,
/// expandable icon rail, and inset content.
Widget animatedSidebarDemo(BuildContext context) =>
    const _AnimatedSidebarDemo();

class _AnimatedSidebarDemo extends StatefulWidget {
  const _AnimatedSidebarDemo();

  @override
  State<_AnimatedSidebarDemo> createState() => _AnimatedSidebarDemoState();
}

class _AnimatedSidebarDemoState extends State<_AnimatedSidebarDemo> {
  String _active = 'people';
  bool _expanded = true;

  static final _quickLinks = BeuiAnimatedSidebarGroup(
    items: [
      BeuiAnimatedSidebarItem(
        id: 'search',
        label: 'Search',
        icon: LucideIcons.search,
      ),
      BeuiAnimatedSidebarItem(
        id: 'ai',
        label: 'AI Assistant',
        icon: LucideIcons.sparkles,
      ),
      BeuiAnimatedSidebarItem(
        id: 'inbox',
        label: 'Inbox',
        icon: LucideIcons.inbox,
        badge: '4',
      ),
    ],
  );

  static final _workspaces = BeuiAnimatedSidebarGroup(
    label: 'Workspaces',
    items: [
      BeuiAnimatedSidebarItem(
        id: 'people',
        label: 'People',
        icon: LucideIcons.circle_user_round,
        children: const [
          BeuiAnimatedSidebarItem(id: 'all-people', label: 'All people'),
          BeuiAnimatedSidebarItem(id: 'recent', label: 'Recent activity'),
          BeuiAnimatedSidebarItem(id: 'segments', label: 'Segments'),
        ],
      ),
      BeuiAnimatedSidebarItem(
        id: 'companies',
        label: 'Companies',
        icon: LucideIcons.building_2,
      ),
      BeuiAnimatedSidebarItem(
        id: 'opportunities',
        label: 'Opportunities',
        icon: LucideIcons.target,
        children: const [
          BeuiAnimatedSidebarItem(id: 'pipeline', label: 'Pipeline'),
          BeuiAnimatedSidebarItem(id: 'forecast', label: 'Forecast'),
          BeuiAnimatedSidebarItem(id: 'closed', label: 'Closed deals'),
        ],
      ),
      BeuiAnimatedSidebarItem(
        id: 'tasks',
        label: 'Tasks',
        icon: LucideIcons.list_todo,
      ),
      BeuiAnimatedSidebarItem(
        id: 'notes',
        label: 'Notes',
        icon: LucideIcons.notebook_tabs,
      ),
      BeuiAnimatedSidebarItem(
        id: 'workflows',
        label: 'Workflows',
        icon: LucideIcons.workflow,
        children: const [
          BeuiAnimatedSidebarItem(id: 'automations', label: 'Automations'),
          BeuiAnimatedSidebarItem(id: 'runs', label: 'Runs'),
          BeuiAnimatedSidebarItem(id: 'templates', label: 'Templates'),
        ],
      ),
      BeuiAnimatedSidebarItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: LucideIcons.layout_grid,
      ),
    ],
  );

  String get _title {
    switch (_active) {
      case 'search':
        return 'Search';
      case 'ai':
        return 'AI Assistant';
      case 'inbox':
        return 'Inbox';
      case 'all-people':
        return 'All people';
      case 'recent':
        return 'Recent activity';
      case 'segments':
        return 'Segments';
      case 'pipeline':
        return 'Pipeline';
      case 'forecast':
        return 'Forecast';
      case 'closed':
        return 'Closed deals';
      case 'automations':
        return 'Automations';
      case 'runs':
        return 'Runs';
      case 'templates':
        return 'Templates';
      case 'companies':
        return 'Companies';
      case 'tasks':
        return 'Tasks';
      case 'notes':
        return 'Notes';
      case 'dashboard':
        return 'Dashboard';
      case 'people':
        return 'People';
      case 'opportunities':
        return 'Opportunities';
      case 'workflows':
        return 'Workflows';
      default:
        return _active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    // Source preview: the bare shell in `w-full px-0 py-2 sm:p-3`, an
    // `h-[720px] rounded-2xl border-foreground/[0.08]` provider — no variant
    // picker (the other variants are covered by the widget tests).
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.foreground.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 720,
            child: BeuiAnimatedSidebar(
              groups: [_quickLinks, _workspaces],
              expanded: _expanded,
              onExpandedChange: (v) => setState(() => _expanded = v),
              selectedId: _active,
              onSelected: (id) => setState(() => _active = id),
              semanticLabel: 'Solace workspace',
              header: _Header(colors: colors),
              footer: _Footer(colors: colors),
              child: _Inset(title: _title, colors: colors),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final scope = BeuiAnimatedSidebarScope.maybeOf(context);
    final expanded = scope?.expanded ?? true;

    // Source preview: `flex min-h-11 items-center gap-3 overflow-hidden px-2`.
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.foreground,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.command,
              size: 16,
              color: colors.background,
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Acme Inc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevrons_up_down,
                    size: 14,
                    color: colors.mutedForeground,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final scope = BeuiAnimatedSidebarScope.maybeOf(context);
    final expanded = scope?.expanded ?? true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        // Source preview: `flex min-h-11 items-center gap-3 rounded-xl p-1`.
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(4),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFD5FF66),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'AS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172000),
                  ),
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ava Stone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        'ava@solace.app',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevron_right,
                  size: 16,
                  color: colors.mutedForeground,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Inset extends StatelessWidget {
  const _Inset({required this.title, required this.colors});

  final String title;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header bar
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              const BeuiAnimatedSidebarTrigger(),
              const SizedBox(width: 12),
              Container(width: 1, height: 20, color: colors.border),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ),
        // Source: `flex-1 flex-col justify-between p-7` — the greeting block
        // pinned to the top, the "Active view" footer to the bottom.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Wednesday, July 29',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Good morning, Ava.',
                      style: TextStyle(
                        fontSize: 24, // sm:text-2xl
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 448),
                      child: Text(
                        'Your workspace stays in place while the navigation '
                        'folds down to a focused icon rail.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7, // leading-6
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.border)),
                  ),
                  padding: const EdgeInsets.only(top: 16), // pt-4
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ACTIVE VIEW',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.6, // tracking-[0.16em]
                              color: colors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.foreground,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Press ⌘B to toggle',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
