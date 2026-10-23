import 'package:flutter/widgets.dart';

import '../uniforms.dart';

/// Spec for the `static-radial-gradient` variant — a still radial gradient (up
/// to 8 colors) with focal point, falloff, distortion and grain. Color 0 is the
/// background (`u_colorBack`); the rest fill the gradient array.
final ShaderSpec beuiStaticRadialGradientSpec = ShaderSpec(
  asset: 'shaders/beui_static_radial_gradient.frag',
  animated: false,
  defaultColors: const [
    Color(0xFF121212), // background
    Color(0xFFF72585),
    Color(0xFF5227FF),
    Color(0xFF8ECAE6),
  ],
  defaultParams: const {
    'radius': 0.6,
    'focalDistance': 0,
    'focalAngle': 0,
    'falloff': 0,
    'mixing': 0.5,
    'distortion': 0,
    'distortionShift': 0,
    'distortionFreq': 4,
    'grainMixer': 0,
    'grainOverlay': 0,
  },
  setUniforms: (ctx) {
    ctx.header(scale: ctx.p('scale', 1));
    final cs = ctx.colors;
    ctx.col(cs.isNotEmpty ? cs[0] : const Color(0xFF121212)); // u_colorBack
    final grad = cs.length > 1 ? cs.sublist(1) : const [Color(0xFFF72585)];
    ctx.colorArray(grad);
    ctx.f(grad.length.toDouble()); // u_colorsCount
    ctx.f(ctx.p('radius', 0.6));
    ctx.f(ctx.p('focalDistance', 0));
    ctx.f(ctx.p('focalAngle', 0));
    ctx.f(ctx.p('falloff', 0));
    ctx.f(ctx.p('mixing', 0.5));
    ctx.f(ctx.p('distortion', 0));
    ctx.f(ctx.p('distortionShift', 0));
    ctx.f(ctx.p('distortionFreq', 4));
    ctx.f(ctx.p('grainMixer', 0));
    ctx.f(ctx.p('grainOverlay', 0));
  },
);
