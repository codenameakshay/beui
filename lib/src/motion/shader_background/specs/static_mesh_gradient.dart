import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `static-mesh-gradient` variant — a still mesh gradient of up to
/// 8 colors with wave distortion and grain.
final ShaderSpec beuiStaticMeshGradientSpec = ShaderSpec(
  asset: 'shaders/beui_static_mesh_gradient.frag',
  animated: false,
  defaultColors: const [
    Color(0xFF121212),
    Color(0xFF3A6EA5),
    Color(0xFF8ECAE6),
    Color(0xFFF2F2F2),
  ],
  defaultParams: const {
    'positions': 2,
    'waveX': 0.5,
    'waveXShift': 0.3,
    'waveY': 0.5,
    'waveYShift': 0.3,
    'mixing': 0.5,
    'grainMixer': 0,
    'grainOverlay': 0,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    ctx.colorArray(ctx.colors);
    ctx.f(ctx.colors.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('positions', 2));
    ctx.f(ctx.p('waveX', 0.5));
    ctx.f(ctx.p('waveXShift', 0.3));
    ctx.f(ctx.p('waveY', 0.5));
    ctx.f(ctx.p('waveYShift', 0.3));
    ctx.f(ctx.p('mixing', 0.5));
    ctx.f(ctx.p('grainMixer', 0));
    ctx.f(ctx.p('grainOverlay', 0));
  },
);
