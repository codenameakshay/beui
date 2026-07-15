#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `waterFragmentShader` (animated, texture).
// The source distorts a user image; to work as a standalone background this
// port feeds the shared noise texture as u_image (sampler 0). Deviations
// (shared — see beui_voronoi.frag): v_imageUV inlined as the [0,1] screen UV;
// fwidth() in getUvFrame -> analytic per-pixel width; helpers inlined.

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846

uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

uniform sampler2D u_image; // sampler 0 (shared noise texture)

uniform vec4 u_colorBack;        // 5..8
uniform vec4 u_colorHighlight;   // 9..12
uniform float u_imageAspectRatio;// 13
uniform float u_size;            // 14
uniform float u_highlights;      // 15
uniform float u_layering;        // 16
uniform float u_edges;           // 17
uniform float u_caustic;         // 18
uniform float u_waves;           // 19

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
mat2 rotate2D(float r) { return mat2(cos(r), sin(r), -sin(r), cos(r)); }

// AA widths passed analytically (fwidth unsupported): per-pixel imageUV step.
float getUvFrame(vec2 uv, vec2 aa) {
  float left = smoothstep(0., aa.x, uv.x);
  float right = 1.0 - smoothstep(1. - aa.x, 1., uv.x);
  float bottom = smoothstep(0., aa.y, uv.y);
  float top = 1.0 - smoothstep(1. - aa.y, 1., uv.y);
  return left * right * bottom * top;
}
float getCausticNoise(vec2 uv, float t, float scale) {
  vec2 n = vec2(.1);
  vec2 N = vec2(.1);
  mat2 m = rotate2D(.5);
  for (int j = 0; j < 6; j++) {
    uv *= m;
    n *= m;
    vec2 q = uv * scale + float(j) + n + (.5 + .5 * float(j)) * (mod(float(j), 2.) - 1.) * t;
    n += sin(q);
    N += cos(q) / scale;
    scale *= 1.1;
  }
  return (N.x + N.y + 1.);
}

void main() {
  vec2 v_imageUV = FlutterFragCoord().xy / u_resolution;
  vec2 aa = 2.0 / u_resolution;

  vec2 imageUV = v_imageUV;
  vec2 patternUV = v_imageUV - .5;
  patternUV = (patternUV * vec2(u_imageAspectRatio, 1.));
  patternUV /= (.01 + .09 * u_size);
  float t = u_time;

  float wavesNoise = snoise((.3 + .1 * sin(t)) * .1 * patternUV + vec2(0., .4 * t));
  float causticNoise = getCausticNoise(patternUV + u_waves * vec2(1., -1.) * wavesNoise, 2. * t, 1.5);
  causticNoise += u_layering * getCausticNoise(patternUV + 2. * u_waves * vec2(1., -1.) * wavesNoise, 1.5 * t, 2.);
  causticNoise = causticNoise * causticNoise;

  float edgesDistortion = smoothstep(0., .1, imageUV.x);
  edgesDistortion *= smoothstep(0., .1, imageUV.y);
  edgesDistortion *= (smoothstep(1., 1.1, imageUV.x) + (1.0 - smoothstep(.8, .95, imageUV.x)));
  edgesDistortion *= (1.0 - smoothstep(.9, 1., imageUV.y));
  edgesDistortion = mix(edgesDistortion, 1., u_edges);

  float causticNoiseDistortion = .02 * causticNoise * edgesDistortion;
  float wavesDistortion = .1 * u_waves * wavesNoise;
  imageUV += vec2(wavesDistortion, -wavesDistortion);
  imageUV += (u_caustic * causticNoiseDistortion);

  float frame = getUvFrame(imageUV, aa);
  vec4 image = texture(u_image, imageUV);
  vec4 backColor = u_colorBack;
  backColor.rgb *= backColor.a;
  vec3 color = mix(backColor.rgb, image.rgb, image.a * frame);
  float opacity = backColor.a + image.a * frame;

  causticNoise = max(-.2, causticNoise);
  float hightlight = .025 * u_highlights * causticNoise;
  hightlight *= u_colorHighlight.a;
  color = mix(color, u_colorHighlight.rgb, .05 * u_highlights * causticNoise);
  opacity += hightlight;
  color += hightlight * (.5 + .5 * wavesNoise);
  opacity += hightlight * (.5 + .5 * wavesNoise);
  opacity = clamp(opacity, 0., 1.);

  fragColor = vec4(color, opacity);
}
