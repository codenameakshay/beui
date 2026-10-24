import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `dot-grid` variant — a static grid of dots (circle / diamond /
/// square / triangle via `shape`), with per-cell size and opacity jitter.
///
/// The three colors map, in declaration order, to `u_colorBack`, `u_colorFill`,
/// `u_colorStroke`.
final ShaderSpec beuiDotGridSpec = ShaderSpec(
  asset: 'shaders/beui_dot_grid.frag',
  animated: false,
  defaultColors: const [
    Color(0xFF0B0B0B), // back
    Color(0xFF3A6EA5), // fill
    Color(0x00000000), // stroke (off by default)
  ],
  defaultParams: const {
    'dotSize': 6,
    'gapX': 40,
    'gapY': 40,
    'strokeWidth': 0,
    'sizeRange': 0,
    'opacityRange': 0,
    'shape': 0,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF0B0B0B)); // u_colorBack
    ctx.col(cs.length > 1 ? cs[1] : const Color(0xFF3A6EA5)); // u_colorFill
    ctx.col(cs.length > 2 ? cs[2] : const Color(0x00000000)); // u_colorStroke
    ctx.f(ctx.p('dotSize', 6));
    ctx.f(ctx.p('gapX', 40));
    ctx.f(ctx.p('gapY', 40));
    ctx.f(ctx.p('strokeWidth', 0));
    ctx.f(ctx.p('sizeRange', 0));
    ctx.f(ctx.p('opacityRange', 0));
    ctx.f(ctx.p('shape', 0));
  },
);
