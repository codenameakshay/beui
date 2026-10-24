#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `simplexNoiseFragmentShader`.
// Deviations from the WebGL source (see docs — all shaders follow these):
//  - The vertex-stage sizing pipeline is inlined: `v_patternUV` is computed
//    from FlutterFragCoord() for the default pattern sizing (fit=none, centered,
//    origin 0.5, no rotation), parameterized by u_scale / u_pixelRatio.
//  - `fwidth()` (unsupported by Impeller) is replaced by an analytic AA width
//    derived from u_resolution.
//  - Helpers (simplex noise, PI, banding fix) are inlined (no #include).

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846
#define MAX_COLORS 8

// Common header (indices 0..4) — every beUI shader shares this prefix.
uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

// Variant uniforms.
uniform vec4 u_colors[MAX_COLORS]; // 5..36
uniform float u_colorsCount;       // 37
uniform float u_stepsPerColor;     // 38
uniform float u_softness;          // 39

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

float getNoise(vec2 uv, float t) {
  float noise = .5 * snoise(uv - vec2(0., .3 * t));
  noise += .5 * snoise(2. * uv + vec2(0., .32 * t));
  return noise;
}

float steppedSmooth(float m, float steps, float softness, float aa) {
  float stepT = floor(m * steps) / steps;
  float f = m * steps - floor(m * steps);
  float fw = steps * aa; // was: steps * fwidth(m)
  float smoothed = smoothstep(.5 - softness, min(1., .5 + softness + fw), f);
  return stepT + smoothed / steps;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uvc = frag / u_resolution - 0.5;
  uvc.y = -uvc.y;
  // Default pattern UV (fit=none): centered pixel space / pixelRatio / scale, *0.01.
  vec2 v_patternUV = uvc * u_resolution / u_pixelRatio / u_scale * 0.01;
  float aa = 1.5 / min(u_resolution.x, u_resolution.y);

  vec2 shape_uv = v_patternUV;
  shape_uv *= .1;

  float t = .2 * u_time;
  float shape = .5 + .5 * getNoise(shape_uv, t);

  float mixer = (shape - .5 / u_colorsCount) * u_colorsCount;
  float steps = max(1., u_stepsPerColor);

  vec4 gradient = u_colors[0];
  gradient.rgb *= gradient.a;
  for (int i = 1; i < MAX_COLORS; i++) {
    if (i >= int(u_colorsCount)) break;
    float localM = clamp(mixer - float(i - 1), 0., 1.);
    localM = steppedSmooth(localM, steps, .5 * u_softness, aa);
    vec4 c = u_colors[i];
    c.rgb *= c.a;
    gradient = mix(gradient, c, localM);
  }

  if ((mixer < 0.) || (mixer > (u_colorsCount - 1.))) {
    float localM = mixer + 1.;
    if (mixer > (u_colorsCount - 1.)) {
      localM = mixer - (u_colorsCount - 1.);
    }
    localM = steppedSmooth(localM, steps, .5 * u_softness, aa);
    vec4 cFst = u_colors[0];
    cFst.rgb *= cFst.a;
    // Impeller rejects dynamic uniform-array indexing, so select the last
    // active color with a constant-indexed loop instead of u_colors[count-1].
    vec4 cLast = u_colors[0];
    for (int k = 0; k < MAX_COLORS; k++) {
      if (k < int(u_colorsCount)) cLast = u_colors[k];
    }
    cLast.rgb *= cLast.a;
    gradient = mix(cLast, cFst, localM);
  }

  vec3 color = gradient.rgb;
  float opacity = gradient.a;

  color += 1. / 256. * (fract(sin(dot(.014 * frag, vec2(12.9898, 78.233))) * 43758.5453123) - .5);

  fragColor = vec4(color, opacity);
}
