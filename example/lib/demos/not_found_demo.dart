import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the not-found variants — pick one with the chips.
Widget notFoundDemo(BuildContext context) => const _NotFoundDemo();

class _NotFoundDemo extends StatefulWidget {
  const _NotFoundDemo();

  @override
  State<_NotFoundDemo> createState() => _NotFoundDemoState();
}

class _NotFoundDemoState extends State<_NotFoundDemo> {
  String _variant = 'glitch';

  @override
  Widget build(BuildContext context) {
    final variants = {
      'glitch': () => const BeuiNotFoundGlitch(),
      'magnetic': () => const BeuiNotFoundMagnetic(),
      'spotlight': () => const BeuiNotFoundSpotlight(),
      'stacked': () => const BeuiNotFoundStacked(),
      'terminal': () => const BeuiNotFoundTerminal(),
    };
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final name in variants.keys)
                BeuiButton(
                  variant: name == _variant
                      ? BeuiButtonVariant.primary
                      : BeuiButtonVariant.outline,
                  size: BeuiButtonSize.sm,
                  onPressed: () => setState(() => _variant = name),
                  child: Text(name),
                ),
            ],
          ),
          KeyedSubtree(key: ValueKey(_variant), child: variants[_variant]!()),
        ],
      ),
    );
  }
}
