import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiTiltCard], plus a second section for [BeuiMagnetic]
/// — the general-purpose "pull toward the cursor" primitive [BeuiMagneticButton]
/// (shown on the button page) builds on.
Widget tiltCardDemo(BuildContext context) {
  final colors = Theme.of(context).extension<BeuiColors>()!;

  Widget cardChrome({required String title, required String body}) => Container(
    width: 280,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: colors.card,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Source: `text-xs uppercase tracking-wider text-muted-foreground`
        // — 12px/16px, 0.05em tracking, regular weight (no font-weight
        // class). Tailwind's leading is set explicitly on each block
        // below; without it Flutter's own defaults make the card ~5px
        // taller.
        Text(
          'PREMIUM',
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12, // text-xs
            letterSpacing: 0.6,
            color: colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 8), // mt-2
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            height: 32 / 24, // text-2xl
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 12), // mt-3
        Text(
          body,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14, // text-sm
            color: colors.mutedForeground,
          ),
        ),
      ],
    ),
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BeuiTiltCard(
        child: cardChrome(
          title: 'Tilt me',
          body: 'Move your cursor across the card to see 3D tilt + glare.',
        ),
      ),
      const SizedBox(height: 40),
      const SectionLabel(
        'Magnetic — the wrapped child leans toward the cursor',
      ),
      const SizedBox(height: 16),
      BeuiMagnetic(
        child: cardChrome(
          title: 'Pull me',
          body: 'Any widget can wrap in BeuiMagnetic, not just buttons.',
        ),
      ),
    ],
  );
}
