import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiAiSidebar] — mirrors the source preview: an
/// animated-sidebar shell with quick actions, a resource tree (folders /
/// projects / files / bookmarks), selection, expand, and rename.
Widget aiSidebarDemo(BuildContext context) => const _AiSidebarDemo();

class _AiSidebarDemo extends StatefulWidget {
  const _AiSidebarDemo();

  @override
  State<_AiSidebarDemo> createState() => _AiSidebarDemoState();
}

class _AiSidebarDemoState extends State<_AiSidebarDemo> {
  static final _resources = <BeuiSidebarResource>[
    const BeuiSidebarResource(
      id: 'design-system',
      label: 'Design system',
      kind: BeuiSidebarResourceKind.project,
    ),
    const BeuiSidebarResource(
      id: 'client-portal',
      label: 'Client portal',
      kind: BeuiSidebarResourceKind.project,
    ),
    const BeuiSidebarResource(
      id: 'marketing-site',
      label: 'Marketing website',
      kind: BeuiSidebarResourceKind.project,
    ),
    const BeuiSidebarResource(
      id: 'platform',
      label: 'Platform',
      kind: BeuiSidebarResourceKind.project,
      children: [
        BeuiSidebarResource(
          id: 'api',
          label: 'API migration',
          kind: BeuiSidebarResourceKind.file,
        ),
        BeuiSidebarResource(
          id: 'billing',
          label: 'Billing states',
          kind: BeuiSidebarResourceKind.file,
        ),
        BeuiSidebarResource(
          id: 'docs',
          label: 'Read platform docs',
          kind: BeuiSidebarResourceKind.bookmark,
        ),
      ],
    ),
    const BeuiSidebarResource(
      id: 'mobile-app',
      label: 'Mobile app',
      kind: BeuiSidebarResourceKind.project,
    ),
    const BeuiSidebarResource(
      id: 'research-lab',
      label: 'Research lab',
      kind: BeuiSidebarResourceKind.folder,
    ),
    const BeuiSidebarResource(
      id: 'agent-workspace',
      label: 'Agent workspace',
      kind: BeuiSidebarResourceKind.project,
      children: [
        BeuiSidebarResource(
          id: 'resource-review',
          label: 'Review resource sidebar interaction details',
          kind: BeuiSidebarResourceKind.file,
        ),
        BeuiSidebarResource(
          id: 'release-offer',
          label: 'Prepare release announcement',
          kind: BeuiSidebarResourceKind.file,
        ),
        BeuiSidebarResource(
          id: 'haptics',
          label: 'Explore interaction feedback',
          kind: BeuiSidebarResourceKind.bookmark,
        ),
        BeuiSidebarResource(
          id: 'promotion',
          label: 'Plan launch distribution',
          kind: BeuiSidebarResourceKind.file,
        ),
        BeuiSidebarResource(
          id: 'motion-research',
          label: 'Research motion implementation patterns',
          kind: BeuiSidebarResourceKind.bookmark,
        ),
      ],
    ),
    const BeuiSidebarResource(
      id: 'release-notes',
      label: 'Release notes',
      kind: BeuiSidebarResourceKind.file,
    ),
    const BeuiSidebarResource(
      id: 'archived',
      label: 'Archived notes',
      kind: BeuiSidebarResourceKind.file,
      disabled: true,
    ),
  ];

  static final _actions = <(String, IconData)>[
    ('New workspace', LucideIcons.square_pen),
    ('Pull requests', LucideIcons.git_pull_request),
    ('Sites', LucideIcons.layout_grid),
    ('Scheduled', LucideIcons.clock_3),
    ('Extensions', LucideIcons.plug),
  ];

  late List<BeuiSidebarResource> _items = List.of(_resources);
  String _active = 'resource-review';
  bool _expanded = true;

  String _labelOf(List<BeuiSidebarResource> items, String id) {
    for (final item in items) {
      if (item.id == id) return item.label;
      final kids = item.children;
      if (kids != null) {
        final found = _labelOf(kids, id);
        if (found != id) return found;
      }
    }
    return id;
  }

  Future<void> _onMove(BeuiSidebarResourceMove move) async {
    // Simulate network latency — reject to test rollback if needed.
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final activeLabel = _labelOf(_items, _active);

    // Source wrapper: `w-full px-0 py-2 sm:p-3`.
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          // rounded-2xl + border-foreground/[0.08]
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.foreground.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 720, // h-[720px]
            child: BeuiAnimatedSidebar(
              // Source group 1: five quick actions, no active state.
              groups: [
                BeuiAnimatedSidebarGroup(
                  items: [
                    for (final (label, icon) in _actions)
                      BeuiAnimatedSidebarItem(
                        id: 'action-$label',
                        label: label,
                        icon: icon,
                      ),
                  ],
                ),
              ],
              // The source renders no active pill on the quick actions; an
              // unmatchable id keeps the sidebar's selection empty.
              defaultSelectedId: '',
              onSelected: (_) {},
              expanded: _expanded,
              onExpandedChange: (v) => setState(() => _expanded = v),
              collapsible: BeuiAnimatedSidebarCollapsible.offcanvas,
              width: 256, // --sidebar-width: 16rem
              semanticLabel: 'Workspace resources',
              // Source group 2: `Projects` label + the flex-1 resource tree.
              panelContent: _ProjectsPane(
                colors: colors,
                tree: BeuiAiSidebar(
                  items: _items,
                  activeId: _active,
                  defaultExpandedIds: const ['platform', 'agent-workspace'],
                  onActiveChange: (id) => setState(() => _active = id),
                  onItemsChange: (next) => setState(() => _items = next),
                  onMove: _onMove,
                ),
              ),
              child: _Detail(colors: colors, activeLabel: activeLabel),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sidebar group 2 — the `Projects` label plus the scrolling resource tree
/// with the source's bottom fade.
class _ProjectsPane extends StatelessWidget {
  const _ProjectsPane({required this.colors, required this.tree});

  final BeuiColors colors;
  final Widget tree;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Content `px-2` (8) + group `px-1` (4).
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `mb-1 h-8 px-2 text-xs font-medium normal-case tracking-normal`
          SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Projects',
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4), // mb-1
          // This is the documented pattern for a scrolling resource tree:
          // the consumer supplies its own scrollable + bottom fade, since
          // BeuiAiSidebar shrink-wraps by default. BeuiAiSidebar.maxHeight
          // is the built-in alternative when a self-contained capped +
          // faded viewport is enough.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32), // pb-8
                    child: tree,
                  ),
                ),
                // `bg-gradient-to-t from-background via-background/80 to-transparent`
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 32,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            colors.background,
                            colors.background.withValues(alpha: 0.8),
                            colors.background.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inset: workspace header + the selected-resource detail (source
/// `AnimatedSidebarInset`).
class _Detail extends StatelessWidget {
  const _Detail({required this.colors, required this.activeLabel});

  final BeuiColors colors;
  final String activeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `flex h-14 shrink-0 items-center justify-between gap-4 border-b px-5`
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              // `-ml-2` on the trigger.
              const Padding(
                padding: EdgeInsets.only(right: 12), // gap-3
                child: BeuiAnimatedSidebarTrigger(),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WORKSPACE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4, // tracking-[0.14em]
                        color: colors.mutedForeground,
                      ),
                    ),
                    Text(
                      'Agent workspace',
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        color: colors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16), // gap-4
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, // px-2.5
                  vertical: 4, // py-1
                ),
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Draft',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32), // sm:p-8
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 576), // max-w-xl
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected resource',
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        letterSpacing: 0,
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8), // mt-2
                    Text(
                      activeLabel,
                      style: TextStyle(
                        fontSize: 24, // sm:text-2xl
                        height: 32 / 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6, // tracking-tight
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12), // mt-3
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 448),
                      child: Text(
                        'Keep the resource tree predictable while files move '
                        'between projects, labels overflow, and folders expand '
                        'around the current selection.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 24 / 14, // leading-6
                          letterSpacing: 0,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32), // mt-8
                    Divider(height: 1, thickness: 1, color: colors.border),
                    const SizedBox(height: 24), // pt-6
                    Text(
                      'Interaction notes',
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12), // mt-3
                    for (final (i, note) in const [
                      'Folders only reveal their contents.',
                      'Files can be selected, moved, or renamed.',
                      'Rejected moves return to their previous location.',
                    ].indexed)
                      Padding(
                        // `space-y-3` — 12 between items, never leading.
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 14,
                            height: 24 / 14, // leading-6
                            letterSpacing: 0,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
