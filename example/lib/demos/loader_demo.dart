import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiLoader] — every [BeuiLoaderVariant] looping side by
/// side in a labelled grid.
Widget loaderDemo(BuildContext context) => const _LoaderDemo();

const _labels = <BeuiLoaderVariant, String>{
  BeuiLoaderVariant.spinner: 'spinner',
  BeuiLoaderVariant.dots: 'dots',
  BeuiLoaderVariant.bars: 'bars',
  BeuiLoaderVariant.dotMatrix: 'dot-matrix',
  BeuiLoaderVariant.dither: 'dither',
  BeuiLoaderVariant.ascii: 'ascii',
  BeuiLoaderVariant.asciiLine: 'ascii-line',
  BeuiLoaderVariant.asciiBraille: 'ascii-braille',
  BeuiLoaderVariant.asciiBlocks: 'ascii-blocks',
  BeuiLoaderVariant.asciiBounce: 'ascii-bounce',
  BeuiLoaderVariant.morph: 'morph',
  BeuiLoaderVariant.comet: 'comet',
  BeuiLoaderVariant.scramble: 'scramble',
  BeuiLoaderVariant.metaballs: 'metaballs',
  BeuiLoaderVariant.newton: 'newton',
  BeuiLoaderVariant.helix: 'helix',
  BeuiLoaderVariant.percent: 'percent',
};

class _LoaderDemo extends StatelessWidget {
  const _LoaderDemo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BeuiColors>()!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            for (final entry in _labels.entries)
              _Cell(
                label: entry.value,
                borderColor: colors.border,
                labelColor: colors.mutedForeground,
                child: BeuiLoader(variant: entry.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.child,
    required this.borderColor,
    required this.labelColor,
  });

  final String label;
  final Widget child;
  final Color borderColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Center(child: child)),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
