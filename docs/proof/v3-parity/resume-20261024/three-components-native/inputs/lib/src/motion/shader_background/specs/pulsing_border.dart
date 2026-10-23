import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `pulsing-border` variant — an animated glowing rounded border
/// with pulsing color spots and smoke, driven by the shared noise texture.
/// Color 0 is the background (`u_colorBack`); the rest are the border spots.
final ShaderSpec beuiPulsingBorderSpec = ShaderSpec(
  asset: 'shaders/beui_pulsing_border.frag',
  animated: true,
  needsNoise: true,
  defaultColors: const [
    Color(0xFF0B0B0B), // background
    Color(0xFF5227FF),
    Color(0xFF8ECAE6),
    Color(0xFFF72585),
  ],
  defaultParams: const {
    'roundness': 0.5,
    'thickness': 0.15,
    'marginLeft': 0.08,
    'marginRight': 0.08,
    'marginTop': 0.08,
    'marginBottom': 0.08,
    'aspectRatio': 0,
    'softness': 0.6,
    'intensity': 0.5,
    'bloom': 0.3,
    'spotSize': 0.35,
    'spots': 3,
    'pulse': 0.4,
    'smoke': 0.4,
    'smokeSize': 0.5,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF0B0B0B)); // u_colorBack
    final spots = cs.length > 1 ? cs.sublist(1) : const [Color(0xFF5227FF)];
    ctx.colorArray(spots);
    ctx.f(spots.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('roundness', 0.5));
    ctx.f(ctx.p('thickness', 0.15));
    ctx.f(ctx.p('marginLeft', 0.08));
    ctx.f(ctx.p('marginRight', 0.08));
    ctx.f(ctx.p('marginTop', 0.08));
    ctx.f(ctx.p('marginBottom', 0.08));
    ctx.f(ctx.p('aspectRatio', 0));
    ctx.f(ctx.p('softness', 0.6));
    ctx.f(ctx.p('intensity', 0.5));
    ctx.f(ctx.p('bloom', 0.3));
    ctx.f(ctx.p('spotSize', 0.35));
    ctx.f(ctx.p('spots', 3));
    ctx.f(ctx.p('pulse', 0.4));
    ctx.f(ctx.p('smoke', 0.4));
    ctx.f(ctx.p('smokeSize', 0.5));
  },
);
