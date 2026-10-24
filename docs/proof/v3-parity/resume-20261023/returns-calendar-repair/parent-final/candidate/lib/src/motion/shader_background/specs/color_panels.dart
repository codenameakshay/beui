import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `color-panels` variant — animated rotating translucent color
/// panels receding into depth. The color list fills the panel palette; the
/// background uses a fixed dark default.
final ShaderSpec beuiColorPanelsSpec = ShaderSpec(
  asset: 'shaders/beui_color_panels.frag',
  animated: true,
  defaultColors: const [
    Color(0xFF5227FF),
    Color(0xFF3A6EA5),
    Color(0xFF8ECAE6),
    Color(0xFFF72585),
    Color(0xFFF9A300),
  ],
  defaultParams: const {
    'density': 0.9,
    'angle1': 0.5,
    'angle2': 0.5,
    'length': 1.1,
    'edges': 0,
    'blur': 0,
    'fadeIn': 0.5,
    'fadeOut': 0.5,
    'gradient': 0.5,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    ctx.colorArray(ctx.colors);
    ctx.f(ctx.colors.length.toDouble()); // u_colorsCount
    ctx.col(const Color(0xFF0B0B0B)); // u_colorBack
    ctx.f(ctx.p('density', 0.9));
    ctx.f(ctx.p('angle1', 0.5));
    ctx.f(ctx.p('angle2', 0.5));
    ctx.f(ctx.p('length', 1.1));
    ctx.f(ctx.p('edges', 0));
    ctx.f(ctx.p('blur', 0));
    ctx.f(ctx.p('fadeIn', 0.5));
    ctx.f(ctx.p('fadeOut', 0.5));
    ctx.f(ctx.p('gradient', 0.5));
  },
);
