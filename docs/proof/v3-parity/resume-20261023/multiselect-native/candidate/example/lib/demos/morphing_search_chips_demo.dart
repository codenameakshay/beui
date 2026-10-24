import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

Widget morphingSearchChipsDemo(BuildContext context) {
  final colors = BeuiColors.resolve(context);
  return SingleChildScrollView(
    child: Center(
      child: Container(
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
              child: LayoutBuilder(
                builder: (context, constraints) => Opacity(
                  opacity: 0.8,
                  child: GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: 3,
                    childAspectRatio:
                        ((constraints.maxWidth - 24) / 3) /
                        ((constraints.maxHeight - 12) / 2),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final colors in const [
                        [Color(0x66FF637E), Color(0x4DFFB86A)],
                        [Color(0x6600BCFF), Color(0x4D7C86FF)],
                        [Color(0x6600D492), Color(0x4D46ECD5)],
                        [Color(0x66FFD230), Color(0x4DFFA1AD)],
                        [Color(0x66A684FF), Color(0x4DF4A8FF)],
                        [Color(0x6646ECD5), Color(0x4D74D4FF)],
                      ])
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: colors,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: BeuiMorphingSearchChips(
                placeholder: 'Search inspiration',
                label: 'Search inspiration',
                defaultChips: ['onboarding'],
                defaultRecents: ['dashboards', 'empty states', 'pricing pages'],
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
    ),
  );
}
