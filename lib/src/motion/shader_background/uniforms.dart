import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Max length of a `uniform vec4 u_colors[N]` array across beUI shaders. Every
/// shader that takes a color list declares exactly this many and reads
/// `u_colorsCount` of them, so the Dart side can pad uniformly.
const int kBeuiShaderMaxColors = 8;

/// Sequential uniform writer + context for a shader variant's setter.
///
/// Uniform floats are set by position, so a variant's [ShaderSpec.setUniforms]
/// must write in the exact declaration order of its `.frag`. Every beUI shader
/// begins with the shared 5-float header — call [header] first — then its own
/// uniforms via [f] / [col] / [colorArray].
class ShaderUniformCtx {
  /// Creates a writer bound to [shader] for one paint.
  ShaderUniformCtx({
    required this.shader,
    required this.size,
    required this.time,
    required this.colors,
    required this.params,
  });

  /// The shader being written to.
  final ui.FragmentShader shader;

  /// Paint size in logical pixels (fed to `u_resolution`).
  final Size size;

  /// Elapsed animation time in seconds (fed to `u_time`; 0 when frozen).
  final double time;

  /// The resolved color list for this variant.
  final List<Color> colors;

  /// Resolved scalar params (already merged with the variant defaults).
  final Map<String, double> params;

  int _i = 0;

  /// Writes one float uniform.
  void f(double v) => shader.setFloat(_i++, v);

  /// Writes a `vec4` color (straight, non-premultiplied RGBA in 0..1 — shaders
  /// premultiply as `c.rgb *= c.a` where the source does).
  void col(Color c) {
    f(c.r);
    f(c.g);
    f(c.b);
    f(c.a);
  }

  /// Writes the shared header: `u_resolution` (vec2), `u_time`, `u_pixelRatio`
  /// (fixed 1 — FlutterFragCoord is already logical), `u_scale`.
  void header({double scale = 1}) {
    f(size.width);
    f(size.height);
    f(time);
    f(1);
    f(scale);
  }

  /// Writes a padded `u_colors[kBeuiShaderMaxColors]` array (unused slots are
  /// transparent black). Does **not** write `u_colorsCount` — the variant does.
  void colorArray(List<Color> cs) {
    for (var k = 0; k < kBeuiShaderMaxColors; k++) {
      col(k < cs.length ? cs[k] : const Color(0x00000000));
    }
  }

  /// A resolved scalar param or [fallback].
  double p(String key, double fallback) => params[key] ?? fallback;
}

/// Static description of one shader variant: its compiled asset, whether it
/// animates (so reduced motion can freeze it), sensible default colors, and the
/// setter that writes its uniforms in declaration order.
@immutable
class ShaderSpec {
  /// Creates a spec.
  const ShaderSpec({
    required this.asset,
    required this.animated,
    required this.defaultColors,
    required this.setUniforms,
    this.defaultParams = const {},
  });

  /// Bare asset path of the compiled `.frag` (e.g.
  /// `shaders/beui_simplex_noise.frag`). The loader tries the consumer-facing
  /// `packages/beui/` prefix first and falls back to this bare path (the key
  /// inside the package's own tests / example).
  final String asset;

  /// Whether the shader reads `u_time`; static patterns set this false.
  final bool animated;

  /// Fallback colors when the caller passes none.
  final List<Color> defaultColors;

  /// Default scalar params, merged under any caller overrides.
  final Map<String, double> defaultParams;

  /// Writes every uniform for one paint, in the `.frag`'s declaration order.
  final void Function(ShaderUniformCtx ctx) setUniforms;
}
