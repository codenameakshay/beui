import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiMarquee].
Widget marqueeDemo(BuildContext context) {
  final colors = Theme.of(context).extension<BeuiColors>()!;
  const logos = [
    'Vercel',
    'Linear',
    'Stripe',
    'Figma',
    'GitHub',
    'Notion',
    'Loom',
    'Raycast',
  ];
  // Mirrors MarqueePreview: a `w-full` marquee whose cards carry `mx-4`
  // (16px) on top of the track's own 16px gap.
  return SizedBox(
    width: double.infinity,
    child: BeuiMarquee(
      duration: const Duration(seconds: 25),
      children: [
        for (final l in logos)
          Container(
            height: 48,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              l,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
          ),
      ],
    ),
  );
}
