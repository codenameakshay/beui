import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCenterMorphModal] — opens a centered panel that
/// unfolds from its exact center toward every edge.
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A full-size surface that unfolds from its exact center and '
                'folds back the same way.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.mutedForeground),
              ),
              const SizedBox(height: 20),
              BeuiButton(
                onPressed: () => setState(() => _open = true),
                child: const Text('Open modal'),
              ),
            ],
          ),
        ),
        BeuiCenterMorphModal(
          open: _open,
          onOpenChange: (v) => setState(() => _open = v),
          label: 'beUI Pro',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32), // p-7 / p-8
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'beUI Pro',
                  style: TextStyle(
                    fontSize: 14,
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
                    height: 1.2,
                    letterSpacing: -0.4,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 12), // mt-3
                Text(
                  'Go beyond individual components with premium animated '
                  'sections and complete Next.js templates.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
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
                BeuiButton(
                  onPressed: () => setState(() => _open = false),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Explore beUI Pro'),
                      SizedBox(width: 8),
                      Icon(LucideIcons.arrow_up_right, size: 16),
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
