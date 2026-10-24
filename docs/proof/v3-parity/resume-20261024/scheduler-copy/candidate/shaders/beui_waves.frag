#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `wavesFragmentShader` (static).
// Deviations (shared — see beui_simplex_noise.frag): v_patternUV inlined;
// fwidth(shape) -> analytic AA from the patternUV per-pixel step and the wave
// frequency (d(shape)/dpixel).

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846

uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2 (unused — static)
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

uniform vec4 u_colorFront;   // 5..8
uniform vec4 u_colorBack;    // 9..12
uniform float u_shape;       // 13
uniform float u_frequency;   // 14
uniform float u_amplitude;   // 15
uniform float u_spacing;     // 16
uniform float u_proportion;  // 17
uniform float u_softness;    // 18

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uvc = frag / u_resolution - 0.5;
  uvc.y = -uvc.y;
  vec2 v_patternUV = uvc * u_resolution / u_pixelRatio / u_scale * 0.01;
  float pxUV = 0.01 / max(u_pixelRatio * u_scale, 1e-3);

  vec2 shape_uv = v_patternUV;
  shape_uv *= 4.;

  float wave = .5 * cos(shape_uv.x * u_frequency * TWO_PI);
  float zigzag = 2. * abs(fract(shape_uv.x * u_frequency) - .5);
  float irregular = sin(shape_uv.x * .25 * u_frequency * TWO_PI) * cos(shape_uv.x * u_frequency * TWO_PI);
  float irregular2 = .75 * (sin(shape_uv.x * u_frequency * TWO_PI) + .5 * cos(shape_uv.x * .5 * u_frequency * TWO_PI));

  float offset = mix(zigzag, wave, smoothstep(0., 1., u_shape));
  offset = mix(offset, irregular, smoothstep(1., 2., u_shape));
  offset = mix(offset, irregular2, smoothstep(2., 3., u_shape));
  offset *= 2. * u_amplitude;

  float spacing = (.001 + u_spacing);
  float shape = .5 + .5 * sin((shape_uv.y + offset) * PI / spacing);

  // fwidth(shape) ~ 0.5 * (PI/spacing) * d(shape_uv.y)/dpixel; d(shape_uv.y) = 4*pxUV.
  float aa = .0001 + 0.5 * (PI / max(spacing, 1e-4)) * (4.0 * pxUV);
  float dc = 1. - clamp(u_proportion, 0., 1.);
  float e0 = dc - u_softness - aa;
  float e1 = dc + u_softness + aa;
  float res = smoothstep(min(e0, e1), max(e0, e1), shape);

  vec3 fgColor = u_colorFront.rgb * u_colorFront.a;
  float fgOpacity = u_colorFront.a;
  vec3 bgColor = u_colorBack.rgb * u_colorBack.a;
  float bgOpacity = u_colorBack.a;

  vec3 color = fgColor * res;
  float opacity = fgOpacity * res;
  color += bgColor * (1. - opacity);
  opacity += bgOpacity * (1. - opacity);

  fragColor = vec4(color, opacity);
}
