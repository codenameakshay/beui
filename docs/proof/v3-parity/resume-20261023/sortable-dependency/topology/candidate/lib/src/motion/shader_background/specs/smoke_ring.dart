import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `smoke-ring` variant — an animated turbulent smoke ring, driven
/// by the shared noise texture. Color 0 is the background (`u_colorBack`); the
/// rest fill the ring gradient.
final ShaderSpec beuiSmokeRingSpec = ShaderSpec(
  asset: 'shaders/beui_smoke_ring.frag',
  animated: true,
  needsNoise: true,
  defaultColors: const [
    Color(0xFF0B0B0B), // background
    Color(0xFF8ECAE6),
    Color(0xFFF2F2F2),
  ],
  defaultParams: const {
    'thickness': 0.5,
    'radius': 0.5,
    'innerShape': 0.5,
    'noiseScale': 1.2,
    'noiseIterations': 8,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF0B0B0B)); // u_colorBack
    final ring = cs.length > 1 ? cs.sublist(1) : const [Color(0xFF8ECAE6)];
    ctx.colorArray(ring);
    ctx.f(ring.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('thickness', 0.5));
    ctx.f(ctx.p('radius', 0.5));
    ctx.f(ctx.p('innerShape', 0.5));
    ctx.f(ctx.p('noiseScale', 1.2));
    ctx.f(ctx.p('noiseIterations', 8));
  },
);
