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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              expanded: _expanded,
              onExpandedChange: (v) => setState(() => _expanded = v),
              selectedId: null,
              onSelected: (_) {},
              collapsible: BeuiAnimatedSidebarCollapsible.offcanvas,
              semanticLabel: 'Workspace resources',
              header: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Projects',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
              // Resource tree fills the content area under the action group.
              // We put the AI sidebar in the inset when collapsed chrome is
              // offcanvas; when open, nest it under groups via a custom child.
              child: _Inset(
                colors: colors,
                activeLabel: activeLabel,
                tree: BeuiAiSidebar(
                  items: _items,
                  activeId: _active,
                  defaultExpandedIds: const ['platform', 'agent-workspace'],
                  onActiveChange: (id) => setState(() => _active = id),
                  onItemsChange: (next) => setState(() => _items = next),
                  onMove: _onMove,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Main panel: selected resource summary + a side-by-side tree for desktop.
///
/// The source nests the AI tree *inside* the animated sidebar content. Our
/// [BeuiAnimatedSidebar] groups API is nav-item oriented, so the demo places
/// the resource tree in the inset with a clear visual hierarchy.
class _Inset extends StatelessWidget {
  const _Inset({
    required this.colors,
    required this.activeLabel,
    required this.tree,
  });

  final BeuiColors colors;
  final String activeLabel;
  final Widget tree;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final detail = _Detail(colors: colors, activeLabel: activeLabel);
        final treePane = ColoredBox(
          color: colors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const BeuiAnimatedSidebarTrigger(),
                    const SizedBox(width: 8),
                    Text(
                      'Projects',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                        children: [tree],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 32,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colors.background.withValues(alpha: 0),
                                colors.background.withValues(alpha: 0.8),
                                colors.background,
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

        if (!wide) {
          return Column(
            children: [
              Expanded(flex: 3, child: treePane),
              Expanded(flex: 2, child: detail),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 280, child: treePane),
            VerticalDivider(width: 1, color: colors.border),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.colors, required this.activeLabel});

  final BeuiColors colors;
  final String activeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
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
                        letterSpacing: 1.4,
                        color: colors.mutedForeground,
                      ),
                    ),
                    Text(
                      'Agent workspace',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
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
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected resource',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeLabel,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Keep the resource tree predictable while files move '
                    'between projects, labels overflow, and folders expand '
                    'around the current selection.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Divider(color: colors.border),
                  const SizedBox(height: 24),
                  Text(
                    'Interaction notes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final note in const [
                    'Folders only reveal their contents.',
                    'Files can be selected, moved (Alt+Shift+arrows), or renamed (F2 / double-tap).',
                    'Rejected moves return to their previous location.',
                    'Pointer drag-and-drop reorder is not ported — use keyboard moves.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•  ',
                            style: TextStyle(color: colors.mutedForeground),
                          ),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
