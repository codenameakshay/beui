import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `grain-gradient` variant — an animated grainy multi-stop
/// gradient over one of seven shape fields, driven by the shared noise texture.
/// Color 0 is the background (`u_colorBack`); the rest fill the gradient.
final ShaderSpec beuiGrainGradientSpec = ShaderSpec(
  asset: 'shaders/beui_grain_gradient.frag',
  animated: true,
  needsNoise: true,
  defaultColors: const [
    Color(0xFF0B0B0B), // background
    Color(0xFF5227FF),
    Color(0xFF8ECAE6),
    Color(0xFFF72585),
  ],
  defaultParams: const {
    'softness': 0.5,
    'intensity': 0.5,
    'noise': 0.25,
    'shape': 1,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF0B0B0B)); // u_colorBack
    final grad = cs.length > 1 ? cs.sublist(1) : const [Color(0xFF5227FF)];
    ctx.colorArray(grad);
    ctx.f(grad.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('softness', 0.5));
    ctx.f(ctx.p('intensity', 0.5));
    ctx.f(ctx.p('noise', 0.25));
    ctx.f(ctx.p('shape', 1));
  },
);
