#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `swirlFragmentShader` (animated).
// Deviations (shared — see beui_mesh_gradient.frag): v_objectUV inlined;
// MAX_COLORS 8; fwidth() → analytic objectUV per-pixel width; banding fix uses
// FlutterFragCoord.

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846
#define MAX_COLORS 8

uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

uniform vec4 u_colorBack;          // 5..8
uniform vec4 u_colors[MAX_COLORS]; // 9..40
uniform float u_colorsCount;       // 41
uniform float u_bandCount;         // 42
uniform float u_twist;             // 43
uniform float u_center;            // 44
uniform float u_proportion;        // 45
uniform float u_softness;          // 46
uniform float u_noise;             // 47
uniform float u_noiseFrequency;    // 48

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
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
  m = m * m; m = m * m;
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

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 ndc = frag / u_resolution - 0.5;
  ndc.y = -ndc.y;
  float minDim = min(u_resolution.x, u_resolution.y);
  vec2 v_objectUV = ndc * (u_resolution / minDim) / u_scale;
  float aaPx = 1.0 / max(minDim * u_scale, 1e-3);

  vec2 shape_uv = v_objectUV;
  float l = length(shape_uv);
  l = max(1e-4, l);

  float t = u_time;
  float angle = ceil(u_bandCount) * atan(shape_uv.y, shape_uv.x) + t;
  float angle_norm = angle / TWO_PI;

  float twist = 3. * clamp(u_twist, 0., 1.);
  float offset = pow(l, -twist) + angle_norm;

  float shape = fract(offset);
  shape = 1. - abs(2. * shape - 1.);
  shape += u_noise * snoise(15. * pow(u_noiseFrequency, 2.) * shape_uv);

  float mid = smoothstep(.2, .2 + .8 * u_center, pow(l, twist));
  shape = mix(0., shape, mid);

  float proportion = clamp(u_proportion, 0., 1.);
  float exponent = mix(.25, 1., proportion * 2.);
  exponent = mix(exponent, 10., max(0., proportion * 2. - 1.));
  shape = pow(shape, exponent);

  float mixer = shape * u_colorsCount;
  vec4 gradient = u_colors[0];
  gradient.rgb *= gradient.a;

  float outerShape = 0.;
  for (int i = 1; i < MAX_COLORS + 1; i++) {
    if (i > int(u_colorsCount)) break;
    float m = clamp(mixer - float(i - 1), 0., 1.);
    float aa = max(aaPx, 1e-4);
    m = smoothstep(.5 - .5 * u_softness - aa, .5 + .5 * u_softness + aa, m);
    if (i == 1) outerShape = m;
    vec4 c = u_colors[i - 1];
    c.rgb *= c.a;
    gradient = mix(gradient, c, m);
  }

  float midAA = 0.1 * aaPx;
  float outerMid = smoothstep(.2, .2 + midAA, pow(l, twist));
  outerShape = mix(0., outerShape, outerMid);

  vec3 color = gradient.rgb * outerShape;
  float opacity = gradient.a * outerShape;

  vec3 bgColor = u_colorBack.rgb * u_colorBack.a;
  color = color + bgColor * (1.0 - opacity);
  opacity = opacity + u_colorBack.a * (1.0 - opacity);

  color += 1. / 256. * (fract(sin(dot(.014 * frag, vec2(12.9898, 78.233))) * 43758.5453123) - .5);

  fragColor = vec4(color, opacity);
}
