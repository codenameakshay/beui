import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `swirl` variant — an animated swirling vortex of banded colors
/// with twist, center falloff and noise. Color 0 is the background
/// (`u_colorBack`); the rest fill the band array.
final ShaderSpec beuiSwirlSpec = ShaderSpec(
  asset: 'shaders/beui_swirl.frag',
  animated: true,
  defaultColors: const [
    Color(0xFF121212), // background
    Color(0xFF5227FF),
    Color(0xFF8ECAE6),
    Color(0xFFF72585),
  ],
  defaultParams: const {
    'bandCount': 4,
    'twist': 0.3,
    'center': 0.5,
    'proportion': 0.5,
    'softness': 0.2,
    'noise': 0,
    'noiseFrequency': 0.5,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF121212)); // u_colorBack
    final bands = cs.length > 1 ? cs.sublist(1) : const [Color(0xFF5227FF)];
    ctx.colorArray(bands);
    ctx.f(bands.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('bandCount', 4));
    ctx.f(ctx.p('twist', 0.3));
    ctx.f(ctx.p('center', 0.5));
    ctx.f(ctx.p('proportion', 0.5));
    ctx.f(ctx.p('softness', 0.2));
    ctx.f(ctx.p('noise', 0));
    ctx.f(ctx.p('noiseFrequency', 0.5));
  },
);
