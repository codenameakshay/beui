import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiLoader] — a faithful port of the source
/// `loader.preview.tsx`: `flex flex-wrap items-center justify-center gap-8 p-8`
/// holding one `flex flex-col items-center gap-4` cell per variant, each a
/// 36px loader over a `text-xs text-muted-foreground` label. Variant order and
/// label casing match the source's `VARIANTS` array exactly.
Widget loaderDemo(BuildContext context) => const _LoaderDemo();

const _variants = <(BeuiLoaderVariant, String)>[
  (BeuiLoaderVariant.spinner, 'Spinner'),
  (BeuiLoaderVariant.dots, 'Dots'),
  (BeuiLoaderVariant.bars, 'Bars'),
  (BeuiLoaderVariant.dotMatrix, 'Dot Matrix'),
  (BeuiLoaderVariant.dither, 'Dither'),
  (BeuiLoaderVariant.morph, 'Morph'),
  (BeuiLoaderVariant.comet, 'Comet'),
  (BeuiLoaderVariant.metaballs, 'Metaballs'),
  (BeuiLoaderVariant.newton, 'Newton'),
  (BeuiLoaderVariant.helix, 'Helix'),
  (BeuiLoaderVariant.scramble, 'Scramble'),
  (BeuiLoaderVariant.percent, 'Percent'),
  (BeuiLoaderVariant.ascii, 'ASCII'),
  (BeuiLoaderVariant.asciiLine, 'ASCII Line'),
  (BeuiLoaderVariant.asciiBraille, 'ASCII Braille'),
  (BeuiLoaderVariant.asciiBlocks, 'ASCII Blocks'),
  (BeuiLoaderVariant.asciiBounce, 'ASCII Bounce'),
];

class _LoaderDemo extends StatelessWidget {
  const _LoaderDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32), // p-8
      child: Center(
        child: Wrap(
          spacing: 32, // gap-8
          runSpacing: 32,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (variant, label) in _variants)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiLoader(variant: variant, size: 36),
                  const SizedBox(height: 16), // gap-4
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
