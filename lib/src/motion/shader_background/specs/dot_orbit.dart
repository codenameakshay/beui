import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `dot-orbit` variant — animated dots orbiting a jittered grid,
/// driven by the shared noise texture. Color 0 is the background
/// (`u_colorBack`); the rest tint the dots.
final ShaderSpec beuiDotOrbitSpec = ShaderSpec(
  asset: 'shaders/beui_dot_orbit.frag',
  animated: true,
  needsNoise: true,
  defaultColors: const [
    Color(0xFF0B0B0B), // background
    Color(0xFF5227FF),
    Color(0xFF8ECAE6),
    Color(0xFFF72585),
  ],
  defaultParams: const {
    'stepsPerColor': 1,
    'size': 0.5,
    'sizeRange': 0,
    'spreading': 0.5,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF0B0B0B)); // u_colorBack
    final dots = cs.length > 1 ? cs.sublist(1) : const [Color(0xFF5227FF)];
    ctx.colorArray(dots);
    ctx.f(dots.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('stepsPerColor', 1));
    ctx.f(ctx.p('size', 0.5));
    ctx.f(ctx.p('sizeRange', 0));
    ctx.f(ctx.p('spreading', 0.5));
  },
);
