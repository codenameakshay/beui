#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `perlinNoiseFragmentShader` (animated).
// Deviations (shared — see beui_simplex_noise.frag): v_patternUV inlined;
// fwidth(noise) → analytic ~1px AA width; colorBandingFix uses FlutterFragCoord.

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846

uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

uniform vec4 u_colorFront;   // 5..8
uniform vec4 u_colorBack;    // 9..12
uniform float u_proportion;  // 13
uniform float u_softness;    // 14
uniform float u_octaveCount; // 15
uniform float u_persistence; // 16
uniform float u_lacunarity;  // 17

out vec4 fragColor;

float hash31(vec3 p) {
  p = fract(p * 0.3183099) + 0.1;
  p += dot(p, p.yzx + 19.19);
  return fract(p.x * (p.y + p.z));
}
vec3 gradientPredefined(float hash) {
  int idx = int(mod(hash * 12.0, 12.0));
  if (idx == 0) return vec3(1, 1, 0);
  if (idx == 1) return vec3(-1, 1, 0);
  if (idx == 2) return vec3(1, -1, 0);
  if (idx == 3) return vec3(-1, -1, 0);
  if (idx == 4) return vec3(1, 0, 1);
  if (idx == 5) return vec3(-1, 0, 1);
  if (idx == 6) return vec3(1, 0, -1);
  if (idx == 7) return vec3(-1, 0, -1);
  if (idx == 8) return vec3(0, 1, 1);
  if (idx == 9) return vec3(0, -1, 1);
  if (idx == 10) return vec3(0, 1, -1);
  return vec3(0, -1, -1);
}
float interpolateSafe(float v000, float v001, float v010, float v011,
float v100, float v101, float v110, float v111, vec3 t) {
  t = clamp(t, 0.0, 1.0);
  float v00 = mix(v000, v100, t.x);
  float v01 = mix(v001, v101, t.x);
  float v10 = mix(v010, v110, t.x);
  float v11 = mix(v011, v111, t.x);
  float v0 = mix(v00, v10, t.y);
  float v1 = mix(v01, v11, t.y);
  return mix(v0, v1, t.z);
}
vec3 fade(vec3 t) { return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); }
float perlinNoise(vec3 position, float seed) {
  position += vec3(seed * 127.1, seed * 311.7, seed * 74.7);
  vec3 i = floor(position);
  vec3 f = fract(position);
  float h000 = hash31(i);
  float h001 = hash31(i + vec3(0, 0, 1));
  float h010 = hash31(i + vec3(0, 1, 0));
  float h011 = hash31(i + vec3(0, 1, 1));
  float h100 = hash31(i + vec3(1, 0, 0));
  float h101 = hash31(i + vec3(1, 0, 1));
  float h110 = hash31(i + vec3(1, 1, 0));
  float h111 = hash31(i + vec3(1, 1, 1));
  float v000 = dot(gradientPredefined(h000), f - vec3(0, 0, 0));
  float v001 = dot(gradientPredefined(h001), f - vec3(0, 0, 1));
  float v010 = dot(gradientPredefined(h010), f - vec3(0, 1, 0));
  float v011 = dot(gradientPredefined(h011), f - vec3(0, 1, 1));
  float v100 = dot(gradientPredefined(h100), f - vec3(1, 0, 0));
  float v101 = dot(gradientPredefined(h101), f - vec3(1, 0, 1));
  float v110 = dot(gradientPredefined(h110), f - vec3(1, 1, 0));
  float v111 = dot(gradientPredefined(h111), f - vec3(1, 1, 1));
  vec3 u = fade(f);
  return interpolateSafe(v000, v001, v010, v011, v100, v101, v110, v111, u);
}
float p_noise(vec3 position, int octaveCount, float persistence, float lacunarity) {
  float value = 0.0;
  float amplitude = 1.0;
  float frequency = 10.0;
  float maxValue = 0.0;
  for (int i = 0; i < 8; i++) {
    if (i >= octaveCount) break;
    float seed = float(i) * 0.7319;
    value += perlinNoise(position * frequency, seed) * amplitude;
    maxValue += amplitude;
    amplitude *= persistence;
    frequency *= lacunarity;
  }
  return value;
}
float get_max_amp(float persistence, float octaveCount) {
  persistence = clamp(persistence * 0.999, 0.0, 0.999);
  octaveCount = clamp(octaveCount, 1.0, 8.0);
  if (abs(persistence - 1.0) < 0.001) return octaveCount;
  return (1.0 - pow(persistence, octaveCount)) / max(1e-4, (1.0 - persistence));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uvc = frag / u_resolution - 0.5;
  uvc.y = -uvc.y;
  vec2 v_patternUV = uvc * u_resolution / u_pixelRatio / u_scale * 0.01;

  vec2 uv = v_patternUV;
  uv *= .5;

  float t = .2 * u_time;
  vec3 p = vec3(uv, t);

  float octCount = clamp(floor(u_octaveCount), 1.0, 8.0);
  float noise = p_noise(p, int(octCount), u_persistence, u_lacunarity);

  float max_amp = get_max_amp(u_persistence, octCount);
  float noise_normalized = clamp((noise + max_amp) / max(1e-4, (2. * max_amp)) + (u_proportion - .5), 0.0, 1.0);
  float sharpness = clamp(u_softness, 0., 1.);
  // fwidth(noise_normalized) → analytic ~1px width.
  float smooth_w = 0.5 * max(2.0 / min(u_resolution.x, u_resolution.y), 0.001);
  float res = smoothstep(
    .5 - .5 * sharpness - smooth_w,
    .5 + .5 * sharpness + smooth_w,
    noise_normalized
  );

  vec3 fgColor = u_colorFront.rgb * u_colorFront.a;
  float fgOpacity = u_colorFront.a;
  vec3 bgColor = u_colorBack.rgb * u_colorBack.a;
  float bgOpacity = u_colorBack.a;

  vec3 color = fgColor * res;
  float opacity = fgOpacity * res;
  color += bgColor * (1. - opacity);
  opacity += bgOpacity * (1. - opacity);

  color += 1. / 256. * (fract(sin(dot(.014 * frag, vec2(12.9898, 78.233))) * 43758.5453123) - .5);

  fragColor = vec4(color, opacity);
}
