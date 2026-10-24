import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCylinderCarousel] — a faithful port of the source
/// `cylinder-carousel.preview.tsx`: `flex w-full flex-col items-center gap-4
/// p-6` holding a segment [BeuiTabs] that flips a single carousel between
/// concave and convex, a `rounded-3xl border bg-muted/20 py-6` stage with one
/// `itemSize: 230, height: 310` carousel, and the 12px muted caption.
///
/// The eight slides are the source's eight [BeuiShaderBackground] presets,
/// each clipped to a bordered circle.
Widget cylinderCarouselDemo(BuildContext context) => const _CylinderDemo();

/// The source's `SLIDES` array. Colour lists follow each spec's own ordering
/// (see `lib/src/motion/shader_background/specs/*.dart`): background-first for
/// metaballs / god-rays / swirl, front-first for dithering and neuro-noise.
const _slides = <(BeuiShaderVariant, List<Color>, double)>[
  (BeuiShaderVariant.dithering, [Color(0xFFB98CFF), Color(0xFF1A1030)], 0.3),
  (
    BeuiShaderVariant.metaballs,
    [
      Color(0xFFC9B9A8),
      Color(0xFFE8E8EF),
      Color(0xFF8A8A9A),
      Color(0xFF1A1A22),
    ],
    0.4,
  ),
  (
    BeuiShaderVariant.warp,
    [
      Color(0xFFC8FF00),
      Color(0xFF3A5A00),
      Color(0xFFC8FF00),
      Color(0xFF88BB00),
    ],
    0.4,
  ),
  (
    BeuiShaderVariant.godRays,
    [Color(0xFF000000), Color(0xFF6A7BFF), Color(0xFF00114D)],
    0.5,
  ),
  (
    BeuiShaderVariant.swirl,
    [
      Color(0xFF1A0000),
      Color(0xFFFFD1A8),
      Color(0xFFFF6A3D),
      Color(0xFFB31A57),
    ],
    0.3,
  ),
  (
    BeuiShaderVariant.meshGradient,
    [
      Color(0xFFE0EAFF),
      Color(0xFF241D9A),
      Color(0xFFF75092),
      Color(0xFF9F50D3),
    ],
    0.3,
  ),
  (BeuiShaderVariant.voronoi, [Color(0xFFFF8247), Color(0xFFFFE53D)], 0.3),
  (
    BeuiShaderVariant.neuroNoise,
    [Color(0xFFFFFFFF), Color(0xFF47A6FF), Color(0xFF000000)],
    0.4,
  ),
];

class _CylinderDemo extends StatefulWidget {
  const _CylinderDemo();

  @override
  State<_CylinderDemo> createState() => _CylinderDemoState();
}

class _CylinderDemoState extends State<_CylinderDemo> {
  BeuiCylinderCurve _curve = BeuiCylinderCurve.concave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Padding(
      padding: const EdgeInsets.all(24), // p-6
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BeuiTabs<BeuiCylinderCurve>(
            variant: BeuiTabsVariant.segment,
            value: _curve,
            onChanged: (v) => setState(() => _curve = v),
            tabs: const [
              BeuiTab(value: BeuiCylinderCurve.concave, label: Text('Concave')),
              BeuiTab(value: BeuiCylinderCurve.convex, label: Text('Convex')),
            ],
          ),
          const SizedBox(height: 16), // gap-4
          // `w-full rounded-3xl border-border/60 bg-muted/20 py-6`, clipped so
          // the rounded corner also clips the composited slides.
          Container(
            decoration: BoxDecoration(
              // Tailwind's `/60` opacity modifier *scales* the token's own
              // alpha — `--border` is already white at 5%, so `border/60` is
              // 3%, not 60%. Setting 0.6 outright drew a near-white hairline.
              color: colors.muted.withValues(alpha: colors.muted.a * 0.2),
              border: Border.all(
                color: colors.border.withValues(alpha: colors.border.a * 0.6),
              ),
              borderRadius: BorderRadius.circular(24), // rounded-3xl
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.symmetric(vertical: 24), // py-6
            child: BeuiCylinderCarousel(
              curve: _curve,
              itemSize: 230,
              height: 310,
              children: [
                for (final (variant, slideColors, speed) in _slides)
                  ClipOval(
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.border.withValues(
                            alpha: colors.border.a * 0.4,
                          ),
                        ),
                      ),
                      child: BeuiShaderBackground(
                        variant: variant,
                        colors: slideColors,
                        speed: speed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16), // gap-4
          Text(
            'Drag, scroll or use arrow keys to roll',
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0, // tracking-normal
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
