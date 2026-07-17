import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `spiral` variant — an animated rotating spiral of stroked
/// stripes with density/distortion/stroke controls. Colors map to
/// `u_colorBack` / `u_colorFront`.
final ShaderSpec beuiSpiralSpec = ShaderSpec(
  asset: 'shaders/beui_spiral.frag',
  animated: true,
  defaultColors: const [Color(0xFF121212), Color(0xFFF2F2F2)],
  defaultParams: const {
    'density': 0.5,
    'distortion': 0,
    'strokeWidth': 0.5,
    'strokeCap': 0,
    'strokeTaper': 0,
    'noise': 0,
    'noiseFrequency': 0.5,
    'softness': 0,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF121212)); // u_colorBack
    ctx.col(cs.length > 1 ? cs[1] : const Color(0xFFF2F2F2)); // u_colorFront
    ctx.f(ctx.p('density', 0.5));
    ctx.f(ctx.p('distortion', 0));
    ctx.f(ctx.p('strokeWidth', 0.5));
    ctx.f(ctx.p('strokeCap', 0));
    ctx.f(ctx.p('strokeTaper', 0));
    ctx.f(ctx.p('noise', 0));
    ctx.f(ctx.p('noiseFrequency', 0.5));
    ctx.f(ctx.p('softness', 0));
  },
);
