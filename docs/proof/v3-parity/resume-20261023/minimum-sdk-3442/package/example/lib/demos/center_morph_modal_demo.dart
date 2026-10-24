import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCenterMorphModal] — mirrors the source
/// `center-morph-modal.preview.tsx`: a single "Open modal" pill that unfolds
/// the beUI Pro panel from its exact centre.
Widget centerMorphModalDemo(BuildContext context) =>
    const _CenterMorphModalDemo();

class _CenterMorphModalDemo extends StatefulWidget {
  const _CenterMorphModalDemo();

  @override
  State<_CenterMorphModalDemo> createState() => _CenterMorphModalDemoState();
}

class _CenterMorphModalDemoState extends State<_CenterMorphModalDemo> {
  bool _open = false;

  static const _features = [
    'Premium animated sections',
    'Complete Next.js templates',
    'Editable source and private registry',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Stack(
      children: [
        Center(
          child: BeuiButton(
            // Source trigger: h-10 rounded-full bg-foreground text-background
            // px-5 text-sm font-medium.
            onPressed: () => setState(() => _open = true),
            child: const Text('Open modal'),
          ),
        ),
        BeuiCenterMorphModal(
          open: _open,
          onOpenChange: (v) => setState(() => _open = v),
          label: 'beUI Pro',
          child: Padding(
            // Source `p-7 sm:p-8` — at the ≥640px preview width that is p-8.
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'beUI Pro',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14, // text-sm
                    fontWeight: FontWeight.w500,
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 20), // mt-5
                Text(
                  'Ship the whole experience.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 32 / 24, // text-2xl
                    letterSpacing: -0.6, // tracking-tight (-0.025em)
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 12), // mt-3
                Text(
                  'Go beyond individual components with premium animated '
                  'sections and complete Next.js templates.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.625, // leading-relaxed
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 28), // mt-7
                Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: colors.border),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 20), // py-5
                  child: Column(
                    children: [
                      for (final feature in _features) ...[
                        if (feature != _features.first)
                          const SizedBox(height: 12), // space-y-3
                        Row(
                          children: [
                            Icon(
                              LucideIcons.check,
                              size: 16,
                              color: colors.mutedForeground,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 20 / 14, // text-sm
                                  color: colors.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28), // mt-7
                // Source CTA: h-11 w-full rounded-full bg-foreground
                // text-background, gap-2 — a full-width pill, not a Button.
                GestureDetector(
                  onTap: () => setState(() => _open = false),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.foreground,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore beUI Pro',
                          style: TextStyle(
                            fontSize: 14,
                            height: 20 / 14, // text-sm
                            fontWeight: FontWeight.w500,
                            color: colors.background,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          LucideIcons.arrow_up_right,
                          size: 16,
                          color: colors.background,
                        ),
                      ],
                    ),
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
