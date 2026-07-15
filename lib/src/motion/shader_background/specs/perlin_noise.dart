import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `perlin-noise` variant — an animated two-color Perlin-noise
/// field with octave/persistence/lacunarity controls. Colors map to
/// `u_colorFront` and `u_colorBack`.
final ShaderSpec beuiPerlinNoiseSpec = ShaderSpec(
  asset: 'shaders/beui_perlin_noise.frag',
  animated: true,
  defaultColors: const [Color(0xFF8ECAE6), Color(0xFF121212)],
  defaultParams: const {
    'proportion': 0.5,
    'softness': 0,
    'octaveCount': 3,
    'persistence': 0.5,
    'lacunarity': 2,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF8ECAE6)); // u_colorFront
    ctx.col(cs.length > 1 ? cs[1] : const Color(0xFF121212)); // u_colorBack
    ctx.f(ctx.p('proportion', 0.5));
    ctx.f(ctx.p('softness', 0));
    ctx.f(ctx.p('octaveCount', 3));
    ctx.f(ctx.p('persistence', 0.5));
    ctx.f(ctx.p('lacunarity', 2));
  },
);
