import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `waves` variant — a static two-color wave pattern (zigzag →
/// sine → irregular via `shape`). Colors map to `u_colorFront` / `u_colorBack`.
final ShaderSpec beuiWavesSpec = ShaderSpec(
  asset: 'shaders/beui_waves.frag',
  animated: false,
  defaultColors: const [Color(0xFFF2F2F2), Color(0xFF121212)],
  defaultParams: const {
    'shape': 1,
    'frequency': 0.5,
    'amplitude': 0.5,
    'spacing': 0.5,
    'proportion': 0.5,
    'softness': 0,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFFF2F2F2)); // u_colorFront
    ctx.col(cs.length > 1 ? cs[1] : const Color(0xFF121212)); // u_colorBack
    ctx.f(ctx.p('shape', 1));
    ctx.f(ctx.p('frequency', 0.5));
    ctx.f(ctx.p('amplitude', 0.5));
    ctx.f(ctx.p('spacing', 0.5));
    ctx.f(ctx.p('proportion', 0.5));
    ctx.f(ctx.p('softness', 0));
  },
);
