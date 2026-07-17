import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `god-rays` variant — animated volumetric light rays radiating
/// from the centre, driven by the shared noise texture. Color 0 is the
/// background (`u_colorBack`); the rest are the ray colors. The bloom overlay
/// uses a fixed default.
final ShaderSpec beuiGodRaysSpec = ShaderSpec(
  asset: 'shaders/beui_god_rays.frag',
  animated: true,
  needsNoise: true,
  defaultColors: const [
    Color(0xFF0B0B0B), // background
    Color(0xFFF9A300),
    Color(0xFFF72585),
    Color(0xFF8ECAE6),
  ],
  defaultParams: const {
    'density': 0.5,
    'spotty': 0.3,
    'midSize': 0.3,
    'midIntensity': 0.3,
    'intensity': 0.5,
    'bloom': 0,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF0B0B0B)); // u_colorBack
    ctx.col(const Color(0x00FFFFFF)); // u_colorBloom (off by default)
    final rays = cs.length > 1 ? cs.sublist(1) : const [Color(0xFFF9A300)];
    ctx.colorArray(rays);
    ctx.f(rays.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('density', 0.5));
    ctx.f(ctx.p('spotty', 0.3));
    ctx.f(ctx.p('midSize', 0.3));
    ctx.f(ctx.p('midIntensity', 0.3));
    ctx.f(ctx.p('intensity', 0.5));
    ctx.f(ctx.p('bloom', 0));
  },
);
