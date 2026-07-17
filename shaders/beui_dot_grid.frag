#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `dotGridFragmentShader` (static).
// Deviations (shared by all beUI shaders — see beui_simplex_noise.frag):
//  - v_patternUV inlined from FlutterFragCoord() (fit=none default sizing).
//  - fwidth() (unsupported by Impeller) → analytic per-pixel width in the
//    pattern-UV space: d(shape_uv)/dpixel = 1 / (u_pixelRatio * u_scale).
//  - declarePI + simplexNoise helpers inlined (no #include).

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846

// Common header (indices 0..4).
uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2 (unused — static)
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

// Variant uniforms.
uniform vec4 u_colorBack;    // 5..8
uniform vec4 u_colorFill;    // 9..12
uniform vec4 u_colorStroke;  // 13..16
uniform float u_dotSize;     // 17
uniform float u_gapX;        // 18
uniform float u_gapY;        // 19
uniform float u_strokeWidth; // 20
uniform float u_sizeRange;   // 21
uniform float u_opacityRange;// 22
uniform float u_shape;       // 23

out vec4 fragColor;

vec3 permute(vec3 x) { return mod(((x * 34.0) + 1.0) * x, 289.0); }
float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
    -0.577350269189626, 0.024390243902439);
  vec2 i = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
    + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy),
      dot(x12.zw, x12.zw)), 0.0);
  m = m * m;
  m = m * m;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

float polygon(vec2 p, float N, float rot) {
  float a = atan(p.x, p.y) + rot;
  float r = TWO_PI / float(N);
  return cos(floor(.5 + a / r) * r - a) * length(p);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uvc = frag / u_resolution - 0.5;
  uvc.y = -uvc.y;
  vec2 v_patternUV = uvc * u_resolution / u_pixelRatio / u_scale * 0.01;

  vec2 shape_uv = 100. * v_patternUV;

  vec2 gap = max(abs(vec2(u_gapX, u_gapY)), vec2(1e-6));
  vec2 grid = fract(shape_uv / gap) + 1e-4;
  vec2 grid_idx = floor(shape_uv / gap);
  float sizeRandomizer = .5 + .8 * snoise(2. * vec2(grid_idx.x * 100., grid_idx.y));
  float opacity_randomizer = .5 + .7 * snoise(2. * vec2(grid_idx.y, grid_idx.x));

  vec2 center = vec2(0.5) - 1e-3;
  vec2 p = (grid - center) * vec2(u_gapX, u_gapY);

  float baseSize = u_dotSize * (1. - sizeRandomizer * u_sizeRange);
  float strokeWidth = u_strokeWidth * (1. - sizeRandomizer * u_sizeRange);

  float dist;
  if (u_shape < 0.5) {
    dist = length(p);
  } else if (u_shape < 1.5) {
    strokeWidth *= 1.5;
    dist = polygon(1.5 * p, 4., .25 * PI);
  } else if (u_shape < 2.5) {
    dist = polygon(1.03 * p, 4., 1e-3);
  } else {
    strokeWidth *= 1.5;
    p = p * 2. - 1.;
    p *= .9;
    p.y = 1. - p.y;
    p.y -= .75 * baseSize;
    dist = polygon(p, 3., 1e-3);
  }

  // fwidth(dist) → analytic: dist tracks shape_uv 1:1, whose per-pixel step is
  // 1 / (u_pixelRatio * u_scale).
  float edgeWidth = 1.0 / max(u_pixelRatio * u_scale, 1e-3);
  float shapeOuter = 1. - smoothstep(baseSize - edgeWidth, baseSize + edgeWidth, dist - strokeWidth);
  float shapeInner = 1. - smoothstep(baseSize - edgeWidth, baseSize + edgeWidth, dist);
  float stroke = shapeOuter - shapeInner;

  float dotOpacity = max(0., 1. - opacity_randomizer * u_opacityRange);
  stroke *= dotOpacity;
  shapeInner *= dotOpacity;

  stroke *= u_colorStroke.a;
  shapeInner *= u_colorFill.a;

  vec3 color = vec3(0.);
  color += stroke * u_colorStroke.rgb;
  color += shapeInner * u_colorFill.rgb;
  color += (1. - shapeInner - stroke) * u_colorBack.rgb * u_colorBack.a;

  float opacity = 0.;
  opacity += stroke;
  opacity += shapeInner;
  opacity += (1. - opacity) * u_colorBack.a;

  fragColor = vec4(color, opacity);
}
