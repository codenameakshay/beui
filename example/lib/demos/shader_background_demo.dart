import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiShaderBackground] — a faithful port of the source
/// `shader-background.preview.tsx`: a `max-w-2xl` column (`gap-5 p-6`) holding
/// an `h-80` bordered `rounded-2xl` stage and a wrapped, centred chip picker
/// over all 27 presets. The picker autoplays every 2400ms and pauses on hover,
/// exactly as the source does.
Widget shaderBackgroundDemo(BuildContext context) => const _ShaderDemo();

/// The source's `AUTOPLAY_MS`.
const _autoplay = Duration(milliseconds: 2400);

/// One entry of the source's `VARIANTS` array.
///
/// The source hands paper-design's React components discrete colour props
/// (`colorBack` / `colorFront` / `colorMid` / `colorFill` / `colorStroke` /
/// `colorHighlight`) alongside a `colors` array. This port folds them into the
/// single ordered [BeuiShaderBackground.colors] list, following each spec's own
/// documented ordering in `lib/src/motion/shader_background/specs/*.dart`.
@immutable
class _Preset {
  const _Preset(
    this.label,
    this.variant,
    this.colors, {
    this.speed = 1,
    this.params = const {},
  });

  final String label;
  final BeuiShaderVariant variant;
  final List<Color> colors;
  final double speed;
  final Map<String, double> params;
}

const _presets = <_Preset>[
  // mesh-gradient: the colour list fills the mesh directly.
  _Preset(
    'Mesh',
    BeuiShaderVariant.meshGradient,
    [
      Color(0xFFE0EAFF),
      Color(0xFF241D9A),
      Color(0xFFF75092),
      Color(0xFF9F50D3),
    ],
    speed: 0.4,
    params: {'distortion': 0.8, 'swirl': 0.3},
  ),
  // grain-gradient: colour 0 is `colorBack`, the rest fill the gradient.
  _Preset(
    'Grain',
    BeuiShaderVariant.grainGradient,
    [
      Color(0xFF000000),
      Color(0xFF7300FF),
      Color(0xFFEBA8FF),
      Color(0xFF00BFFF),
      Color(0xFF2A00FF),
    ],
    speed: 0.5,
    params: {'softness': 0.6},
  ),
  _Preset(
    'Grain — Sunset',
    BeuiShaderVariant.grainGradient,
    [
      Color(0xFF1A0500),
      Color(0xFFFF7A00),
      Color(0xFFFF2E93),
      Color(0xFFFFCE54),
      Color(0xFF8A2BE2),
    ],
    speed: 0.4,
    params: {'softness': 0.7},
  ),
  _Preset(
    'Grain — Pastel',
    BeuiShaderVariant.grainGradient,
    [
      Color(0xFFFFFFFF),
      Color(0xFFFFD6E8),
      Color(0xFFC9E4FF),
      Color(0xFFFFF3C4),
      Color(0xFFD9C9FF),
    ],
    speed: 0.3,
    params: {'softness': 0.85},
  ),
  _Preset(
    'Mesh — Aurora',
    BeuiShaderVariant.meshGradient,
    [
      Color(0xFF00FFB2),
      Color(0xFF0072FF),
      Color(0xFFA200FF),
      Color(0xFF001A2C),
    ],
    speed: 0.3,
    params: {'distortion': 0.6, 'swirl': 0.5},
  ),
  _Preset(
    'Mesh — Citrus',
    BeuiShaderVariant.meshGradient,
    [
      Color(0xFFFFF200),
      Color(0xFFFF8A00),
      Color(0xFFFF3D00),
      Color(0xFFFFE08A),
    ],
    speed: 0.5,
    params: {'distortion': 0.7, 'swirl': 0.4},
  ),
  // warp: the colour list fills the gradient array in order.
  _Preset('Warp', BeuiShaderVariant.warp, [
    Color(0xFF121212),
    Color(0xFF9470FF),
    Color(0xFF121212),
    Color(0xFF8838FF),
  ], speed: 0.4),
  // waves: `colorFront` then `colorBack`. Static — the source passes no speed.
  _Preset('Waves', BeuiShaderVariant.waves, [
    Color(0xFFFFBB00),
    Color(0xFF000000),
  ]),
  // voronoi: the colour list fills the cell palette.
  _Preset('Voronoi', BeuiShaderVariant.voronoi, [
    Color(0xFFFF8247),
    Color(0xFFFFE53D),
  ], speed: 0.3),
  // swirl: colour 0 is `colorBack`, the rest are the bands.
  _Preset('Swirl', BeuiShaderVariant.swirl, [
    Color(0xFF180018),
    Color(0xFFFFD1D1),
    Color(0xFFFF8A8A),
    Color(0xFF660000),
  ], speed: 0.2),
  // dot-orbit: colour 0 is `colorBack`, the rest tint the dots.
  _Preset('Orbit', BeuiShaderVariant.dotOrbit, [
    Color(0xFF000000),
    Color(0xFFFFC96B),
    Color(0xFFFF6200),
    Color(0xFFFF2F00),
  ], speed: 0.6),
  // dot-grid: `colorBack`, `colorFill`, `colorStroke`.
  _Preset('Grid', BeuiShaderVariant.dotGrid, [
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFFFAA00),
  ]),
  // smoke-ring: colour 0 is `colorBack`, the rest fill the ring.
  _Preset('Smoke', BeuiShaderVariant.smokeRing, [
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ], speed: 0.3),
  // static-radial-gradient: colour 0 is `colorBack`.
  _Preset('Radial', BeuiShaderVariant.staticRadialGradient, [
    Color(0xFF000000),
    Color(0xFF00BBFF),
    Color(0xFF00FFE1),
    Color(0xFFFFFFFF),
  ]),
  // neuro-noise: `colorFront`, `colorMid`, `colorBack`.
  _Preset('Neuro', BeuiShaderVariant.neuroNoise, [
    Color(0xFFFFFFFF),
    Color(0xFF47A6FF),
    Color(0xFF000000),
  ], speed: 0.4),
  // water: `colorBack` (the base) then `colorHighlight`.
  _Preset('Water', BeuiShaderVariant.water, [
    Color(0xFF909090),
    Color(0xFFFFFFFF),
  ], speed: 0.4),
  // metaballs: colour 0 is `colorBack`, the rest tint the balls.
  _Preset('Metaballs', BeuiShaderVariant.metaballs, [
    Color(0xFF000000),
    Color(0xFFFF5CF4),
    Color(0xFF4D9EFF),
    Color(0xFF000000),
  ], speed: 0.5),
  // god-rays: colour 0 is `colorBack`, the rest are the ray colours.
  _Preset('Rays', BeuiShaderVariant.godRays, [
    Color(0xFF000000),
    Color(0xFFFFCC66),
    Color(0xFFFF6A00),
  ], speed: 0.4),
  // spiral: `colorBack` then `colorFront`.
  _Preset('Spiral', BeuiShaderVariant.spiral, [
    Color(0xFF7A5CFF),
    Color(0xFFFF5CA6),
    Color(0xFF000000),
  ], speed: 0.4),
  // dithering: `colorFront` then `colorBack`.
  _Preset('Dither', BeuiShaderVariant.dithering, [
    Color(0xFF00FF9D),
    Color(0xFF000000),
  ], speed: 0.4),
  // pulsing-border: colour 0 is `colorBack`, the rest are the spots.
  _Preset('Pulse', BeuiShaderVariant.pulsingBorder, [
    Color(0xFF000000),
    Color(0xFF00E5FF),
    Color(0xFF7000FF),
    Color(0xFFFF00C8),
  ], speed: 0.5),
  // color-panels: the colour list fills the panel palette.
  _Preset('Panels', BeuiShaderVariant.colorPanels, [
    Color(0xFFFF3D68),
    Color(0xFFFFB800),
    Color(0xFF3D7AFF),
    Color(0xFF00FFB2),
  ], speed: 0.3),
  _Preset('Static Mesh', BeuiShaderVariant.staticMeshGradient, [
    Color(0xFFFF8A3D),
    Color(0xFFFF3D9A),
    Color(0xFF3D5AFF),
    Color(0xFF0A0A0A),
  ]),
  _Preset('Static Mesh — Dusk', BeuiShaderVariant.staticMeshGradient, [
    Color(0xFF2B1055),
    Color(0xFF7597DE),
    Color(0xFFF6A1C8),
    Color(0xFF0D0221),
  ]),
  _Preset('Radial — Ember', BeuiShaderVariant.staticRadialGradient, [
    Color(0xFF0A0000),
    Color(0xFFFF5100),
    Color(0xFFFFCE00),
    Color(0xFF4A0000),
  ]),
  _Preset('Simplex', BeuiShaderVariant.simplexNoise, [
    Color(0xFFFF6EC7),
    Color(0xFF6EC7FF),
    Color(0xFF000000),
  ], speed: 0.4),
  // perlin-noise: `colorFront` then `colorBack`.
  _Preset('Perlin', BeuiShaderVariant.perlinNoise, [
    Color(0xFF00FFD5),
    Color(0xFF000000),
  ], speed: 0.3),
];

class _ShaderDemo extends StatefulWidget {
  const _ShaderDemo();

  @override
  State<_ShaderDemo> createState() => _ShaderDemoState();
}

class _ShaderDemoState extends State<_ShaderDemo> {
  int _active = 0;
  bool _paused = false;
  bool _reduce = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// The source's autoplay effect: cycle every [_autoplay], but not while the
  /// pointer is inside (so picking a variant by hand sticks) and not under
  /// reduced motion.
  void _syncTimer() {
    final wanted = !_reduce && !_paused;
    if (wanted == (_timer != null)) return;
    if (!wanted) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer = Timer.periodic(_autoplay, (_) {
      if (mounted) setState(() => _active = (_active + 1) % _presets.length);
    });
  }

  void _setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    _syncTimer();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final current = _presets[_active];

    return MouseRegion(
      onEnter: (_) => _setPaused(true),
      onExit: (_) => _setPaused(false),
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
          child: Padding(
            padding: const EdgeInsets.all(24), // p-6
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // `relative h-80 w-full overflow-hidden rounded-2xl border`.
                Container(
                  height: 320, // h-80
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), // rounded-2xl
                    border: Border.all(color: colors.border),
                  ),
                  // Keyed like the source's `key={current.id}` so switching
                  // presets remounts the shader and restarts its clock.
                  child: BeuiShaderBackground(
                    key: ValueKey(_active),
                    variant: current.variant,
                    colors: current.colors,
                    speed: current.speed,
                    params: current.params,
                  ),
                ),
                const SizedBox(height: 20), // gap-5
                // `TabsList className="flex-wrap justify-center gap-2
                // rounded-2xl"` with `px-4 py-2 text-sm` triggers.
                BeuiTabs<int>(
                  value: _active,
                  onChanged: (i) => setState(() => _active = i),
                  wrap: true,
                  gap: 8, // gap-2
                  listBorderRadius: BorderRadius.circular(16), // rounded-2xl
                  triggerPadding: const EdgeInsets.symmetric(
                    horizontal: 16, // px-4
                    vertical: 8, // py-2
                  ),
                  tabs: [
                    for (var i = 0; i < _presets.length; i++)
                      BeuiTab(value: i, label: Text(_presets[i].label)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
