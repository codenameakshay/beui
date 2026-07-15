import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `neuro-noise` variant — an animated organic neuro-noise field.
/// Colors map to `u_colorFront` / `u_colorMid` / `u_colorBack`.
final ShaderSpec beuiNeuroNoiseSpec = ShaderSpec(
  asset: 'shaders/beui_neuro_noise.frag',
  animated: true,
  defaultColors: const [
    Color(0xFF8ECAE6),
    Color(0xFF3A6EA5),
    Color(0xFF0B0B0B),
  ],
  defaultParams: const {'brightness': 0.2, 'contrast': 0.2},
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF8ECAE6)); // u_colorFront
    ctx.col(cs.length > 1 ? cs[1] : const Color(0xFF3A6EA5)); // u_colorMid
    ctx.col(cs.length > 2 ? cs[2] : const Color(0xFF0B0B0B)); // u_colorBack
    ctx.f(ctx.p('brightness', 0.2));
    ctx.f(ctx.p('contrast', 0.2));
  },
);
