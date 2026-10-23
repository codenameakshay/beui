import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `warp` variant — an animated warping domain-distortion gradient,
/// driven by the shared noise texture.
final ShaderSpec beuiWarpSpec = ShaderSpec(
  asset: 'shaders/beui_warp.frag',
  animated: true,
  needsNoise: true,
  defaultColors: const [
    Color(0xFF5227FF),
    Color(0xFF8ECAE6),
    Color(0xFFF72585),
  ],
  defaultParams: const {
    'proportion': 0.5,
    'softness': 1,
    'shape': 0,
    'shapeScale': 0.5,
    'distortion': 0.25,
    'swirl': 0.5,
    'swirlIterations': 8,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    ctx.colorArray(ctx.colors);
    ctx.f(ctx.colors.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('proportion', 0.5));
    ctx.f(ctx.p('softness', 1));
    ctx.f(ctx.p('shape', 0));
    ctx.f(ctx.p('shapeScale', 0.5));
    ctx.f(ctx.p('distortion', 0.25));
    ctx.f(ctx.p('swirl', 0.5));
    ctx.f(ctx.p('swirlIterations', 8));
  },
);
