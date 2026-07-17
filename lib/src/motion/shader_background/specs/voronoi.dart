import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `voronoi` variant — animated Voronoi cells with glow and gap
/// coloring, driven by the shared noise texture. The color list fills the cell
/// palette; the glow and gap colors use fixed defaults.
final ShaderSpec beuiVoronoiSpec = ShaderSpec(
  asset: 'shaders/beui_voronoi.frag',
  animated: true,
  needsNoise: true,
  defaultColors: const [
    Color(0xFF5227FF),
    Color(0xFF3A6EA5),
    Color(0xFF8ECAE6),
    Color(0xFFF72585),
  ],
  defaultParams: const {
    'stepsPerColor': 1,
    'distortion': 0.35,
    'gap': 0.05,
    'glow': 0,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    ctx.colorArray(ctx.colors);
    ctx.f(ctx.colors.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('stepsPerColor', 1));
    ctx.col(const Color(0x00FFFFFF)); // u_colorGlow (off by default)
    ctx.col(const Color(0xFF0B0B0B)); // u_colorGap (dark gaps)
    ctx.f(ctx.p('distortion', 0.35));
    ctx.f(ctx.p('gap', 0.05));
    ctx.f(ctx.p('glow', 0));
  },
);
