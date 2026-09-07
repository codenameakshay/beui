import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the not-found variants — pick one with the chips.
Widget notFoundDemo(BuildContext context) => const _NotFoundDemo();

enum _NotFoundVariant {
  glitch,
  magnetic,
  spotlight,
  stacked,
  terminal;

  Widget build() => switch (this) {
    _NotFoundVariant.glitch => const BeuiNotFoundGlitch(),
    _NotFoundVariant.magnetic => const BeuiNotFoundMagnetic(),
    _NotFoundVariant.spotlight => const BeuiNotFoundSpotlight(),
    _NotFoundVariant.stacked => const BeuiNotFoundStacked(),
    _NotFoundVariant.terminal => const BeuiNotFoundTerminal(),
  };
}

class _NotFoundDemo extends StatefulWidget {
  const _NotFoundDemo();

  @override
  State<_NotFoundDemo> createState() => _NotFoundDemoState();
}

class _NotFoundDemoState extends State<_NotFoundDemo> {
  _NotFoundVariant _variant = _NotFoundVariant.glitch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final variant in _NotFoundVariant.values)
                BeuiButton(
                  variant: variant == _variant
                      ? BeuiButtonVariant.primary
                      : BeuiButtonVariant.outline,
                  size: BeuiButtonSize.sm,
                  onPressed: () => setState(() => _variant = variant),
                  child: Text(variant.name),
                ),
            ],
          ),
          KeyedSubtree(key: ValueKey(_variant), child: _variant.build()),
        ],
      ),
    );
  }
}
