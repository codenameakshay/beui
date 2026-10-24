import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Stacks both Morphing Search install targets, matching their source previews.
Widget morphingSearchDemo(BuildContext context) => const _StackedDemos();

class _StackedDemos extends StatelessWidget {
  const _StackedDemos();

  static const _items = [
    BeuiMorphingSearchItem(
      id: 'project-folder',
      title: 'Project Folder',
      description: 'Block · Files and previews',
      keywords: ['files', 'overlay'],
      icon: LucideIcons.folder_closed,
    ),
    BeuiMorphingSearchItem(
      id: 'motion-components',
      title: 'Motion components',
      description: 'Collection · Interaction primitives',
      keywords: ['animation', 'components'],
      icon: LucideIcons.layout_grid,
    ),
    BeuiMorphingSearchItem(
      id: 'agent-interfaces',
      title: 'Agent interfaces',
      description: 'Collection · AI building blocks',
      keywords: ['ai', 'chat'],
      icon: LucideIcons.bot,
    ),
    BeuiMorphingSearchItem(
      id: 'installation',
      title: 'Installation guide',
      description: 'Documentation · Add your first component',
      keywords: ['setup', 'shadcn'],
      icon: LucideIcons.book_open,
    ),
    BeuiMorphingSearchItem(
      id: 'design-tokens',
      title: 'Design tokens',
      description: 'Documentation · Color, type, and motion',
      keywords: ['theme', 'styles'],
      icon: LucideIcons.palette,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: const [
              BeuiMorphingSearch(items: _items, placeholder: 'Find components'),
              BeuiMorphingSearch(
                items: _items,
                placeholder: 'Find components',
                shortcut: '',
                iconOnly: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            constraints: const BoxConstraints(maxWidth: 672),
            height: 440,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.muted.withValues(alpha: .4),
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final color in const [
                        Color(0x66fb7185),
                        Color(0x6653c5e8),
                        Color(0x6650d6a5),
                        Color(0x66fbbf24),
                        Color(0x66c084fc),
                        Color(0x6662d5cf),
                      ])
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                    ],
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: BeuiMorphingSearchChips(
                    placeholder: 'Search inspiration',
                    label: 'Search inspiration',
                    defaultChips: ['onboarding'],
                    defaultRecents: [
                      'dashboards',
                      'empty states',
                      'pricing pages',
                    ],
                    storageKey: 'beui:morphing-search-chips:recents',
                    maxChips: 4,
                    suggestions: [
                      'dashboards',
                      'data tables',
                      'dark mode',
                      'empty states',
                      'onboarding',
                      'pricing pages',
                      'settings',
                      'sign in',
                    ],
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
