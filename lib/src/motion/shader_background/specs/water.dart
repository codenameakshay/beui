import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `water` variant — animated caustic water. The source distorts a
/// user image; this port feeds the shared noise texture as the image so it
/// works standalone as a background. Color 0 is the base (`u_colorBack`), color
/// 1 the caustic highlight (`u_colorHighlight`).
final ShaderSpec beuiWaterSpec = ShaderSpec(
  asset: 'shaders/beui_water.frag',
  animated: true,
  needsNoise: true,
  defaultColors: const [Color(0xFF0A2540), Color(0xFF8ECAE6)],
  defaultParams: const {
    'imageAspectRatio': 1,
    'size': 0.5,
    'highlights': 0.6,
    'layering': 0.5,
    'edges': 1,
    'caustic': 0.6,
    'waves': 0.4,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF0A2540)); // u_colorBack
    ctx.col(cs.length > 1 ? cs[1] : const Color(0xFF8ECAE6)); // u_colorHighlight
    ctx.f(ctx.p('imageAspectRatio', 1));
    ctx.f(ctx.p('size', 0.5));
    ctx.f(ctx.p('highlights', 0.6));
    ctx.f(ctx.p('layering', 0.5));
    ctx.f(ctx.p('edges', 1));
    ctx.f(ctx.p('caustic', 0.6));
    ctx.f(ctx.p('waves', 0.4));
  },
);
