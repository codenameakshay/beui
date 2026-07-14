import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `simplex-noise` variant — a stepped, soft simplex-noise
/// gradient field that drifts over time.
final ShaderSpec beuiSimplexNoiseSpec = ShaderSpec(
  asset: 'shaders/beui_simplex_noise.frag',
  animated: true,
  defaultColors: const [
    Color(0xFF121212),
    Color(0xFF3A6EA5),
    Color(0xFF8ECae6),
    Color(0xFFF2F2F2),
  ],
  defaultParams: const {'stepsPerColor': 1, 'softness': 0.5},
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    ctx.colorArray(ctx.colors);
    ctx.f(ctx.colors.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('stepsPerColor', 1)); // u_stepsPerColor
    ctx.f(ctx.p('softness', 0.5)); // u_softness
  },
);
