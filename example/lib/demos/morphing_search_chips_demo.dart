import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

Widget morphingSearchChipsDemo(BuildContext context) {
  final colors = BeuiColors.resolve(context);
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
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
