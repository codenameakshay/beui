import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `dithering` variant — an animated shape ordered-dithered into
/// two colors. `type` picks the dither (1 = random, 2/3/4 = Bayer 2/4/8);
/// `shape` picks the underlying field. Colors map to `u_colorFront` /
/// `u_colorBack`.
final ShaderSpec beuiDitheringSpec = ShaderSpec(
  asset: 'shaders/beui_dithering.frag',
  animated: true,
  defaultColors: const [Color(0xFF8ECAE6), Color(0xFF0B0B0B)],
  defaultParams: const {'pxSize': 2, 'shape': 1, 'type': 4},
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.f(ctx.p('pxSize', 2));
    ctx.col(cs.length > 1 ? cs[1] : const Color(0xFF0B0B0B)); // u_colorBack
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF8ECAE6)); // u_colorFront
    ctx.f(ctx.p('shape', 1));
    ctx.f(ctx.p('type', 4));
  },
);
