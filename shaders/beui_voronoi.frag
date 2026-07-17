#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `voronoiFragmentShader` (animated, texture).
// Deviations (shared — see beui_simplex_noise.frag): v_patternUV inlined;
// MAX_COLORS 8 (source 5); dynamic u_colors[count-1] -> constant-indexed loop;
// textureRandomizerGB inlined against the shared u_noiseTexture sampler.

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846
#define MAX_COLORS 8

uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

uniform sampler2D u_noiseTexture; // sampler 0

uniform vec4 u_colors[MAX_COLORS]; // 5..36
uniform float u_colorsCount;       // 37
uniform float u_stepsPerColor;     // 38
uniform vec4 u_colorGlow;          // 39..42
uniform vec4 u_colorGap;           // 43..46
uniform float u_distortion;        // 47
uniform float u_gap;               // 48
uniform float u_glow;              // 49

out vec4 fragColor;

vec2 randomGB(vec2 p) {
  vec2 uv = floor(p) / 100. + .5;
  return texture(u_noiseTexture, fract(uv)).gb;
}

vec4 voronoi(vec2 x, float t) {
  vec2 ip = floor(x);
  vec2 fp = fract(x);
  vec2 mg, mr;
  float md = 8.;
  float rand = 0.;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 g = vec2(float(i), float(j));
      vec2 o = randomGB(ip + g);
      float raw_hash = o.x;
      o = .5 + u_distortion * sin(t + TWO_PI * o);
      vec2 r = g + o - fp;
      float d = dot(r, r);
      if (d < md) { md = d; mr = r; mg = g; rand = raw_hash; }
    }
  }
  md = 8.;
  for (int j = -2; j <= 2; j++) {
    for (int i = -2; i <= 2; i++) {
      vec2 g = mg + vec2(float(i), float(j));
      vec2 o = randomGB(ip + g);
      o = .5 + u_distortion * sin(t + TWO_PI * o);
      vec2 r = g + o - fp;
      if (dot(mr - r, mr - r) > .00001) {
        md = min(md, dot(.5 * (mr + r), normalize(r - mr)));
      }
    }
  }
  return vec4(md, mr, rand);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uvc = frag / u_resolution - 0.5;
  uvc.y = -uvc.y;
  vec2 v_patternUV = uvc * u_resolution / u_pixelRatio / u_scale * 0.01;

  vec2 shape_uv = v_patternUV;
  shape_uv *= 1.25;

  float t = u_time;
  vec4 voronoiRes = voronoi(shape_uv, t);

  float shape = clamp(voronoiRes.w, 0., 1.);
  float mixer = (shape - .5 / u_colorsCount) * u_colorsCount;
  float steps = max(1., u_stepsPerColor);

  vec4 gradient = u_colors[0];
  gradient.rgb *= gradient.a;
  for (int i = 1; i < MAX_COLORS; i++) {
    if (i >= int(u_colorsCount)) break;
    float localT = clamp(mixer - float(i - 1), 0.0, 1.0);
    localT = round(localT * steps) / steps;
    vec4 c = u_colors[i];
    c.rgb *= c.a;
    gradient = mix(gradient, c, localT);
  }

  if ((mixer < 0.) || (mixer > (u_colorsCount - 1.))) {
    float localT = mixer + 1.;
    if (mixer > (u_colorsCount - 1.)) localT = mixer - (u_colorsCount - 1.);
    localT = round(localT * steps) / steps;
    vec4 cFst = u_colors[0];
    cFst.rgb *= cFst.a;
    vec4 cLast = u_colors[0];
    for (int k = 0; k < MAX_COLORS; k++) {
      if (k < int(u_colorsCount)) cLast = u_colors[k];
    }
    cLast.rgb *= cLast.a;
    gradient = mix(cLast, cFst, localT);
  }

  vec3 cellColor = gradient.rgb;
  float cellOpacity = gradient.a;

  float glows = length(voronoiRes.yz * u_glow);
  glows = pow(glows, 1.5);

  vec3 color = mix(cellColor, u_colorGlow.rgb * u_colorGlow.a, u_colorGlow.a * glows);
  float opacity = cellOpacity + u_colorGlow.a * glows;

  float edge = voronoiRes.x;
  float smoothEdge = .02 / (2. * u_scale) * (1. + .5 * u_gap);
  edge = smoothstep(u_gap - smoothEdge, u_gap + smoothEdge, edge);

  color = mix(u_colorGap.rgb * u_colorGap.a, color, edge);
  opacity = mix(u_colorGap.a, opacity, edge);

  fragColor = vec4(color, opacity);
}
