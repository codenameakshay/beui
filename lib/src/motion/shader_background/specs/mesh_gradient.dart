import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `mesh-gradient` variant — an animated flowing mesh of up to 8
/// colors with distortion, swirl and grain.
final ShaderSpec beuiMeshGradientSpec = ShaderSpec(
  asset: 'shaders/beui_mesh_gradient.frag',
  animated: true,
  defaultColors: const [
    Color(0xFF5227FF),
    Color(0xFF3A6EA5),
    Color(0xFF8ECAE6),
    Color(0xFFF72585),
  ],
  defaultParams: const {
    'distortion': 0.8,
    'swirl': 0.1,
    'grainMixer': 0,
    'grainOverlay': 0,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    ctx.colorArray(ctx.colors);
    ctx.f(ctx.colors.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('distortion', 0.8));
    ctx.f(ctx.p('swirl', 0.1));
    ctx.f(ctx.p('grainMixer', 0));
    ctx.f(ctx.p('grainOverlay', 0));
  },
);
