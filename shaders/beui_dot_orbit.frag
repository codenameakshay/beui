#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `dotOrbitFragmentShader` (animated, texture).
// Deviations (shared — see beui_voronoi.frag): v_patternUV inlined; MAX_COLORS 8
// (source 10); dynamic u_colors[count-1] -> constant-index loop; fwidth(dist)
// -> analytic patternUV AA; randomR/randomGB inlined.

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846
#define MAX_COLORS 8

uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

uniform sampler2D u_noiseTexture; // sampler 0

uniform vec4 u_colorBack;          // 5..8
uniform vec4 u_colors[MAX_COLORS]; // 9..40
uniform float u_colorsCount;       // 41
uniform float u_stepsPerColor;     // 42
uniform float u_size;              // 43
uniform float u_sizeRange;         // 44
uniform float u_spreading;         // 45

out vec4 fragColor;

vec2 rotate(vec2 uv, float th) {
  return mat2(cos(th), sin(th), -sin(th), cos(th)) * uv;
}
float randomR(vec2 p) {
  vec2 uv = floor(p) / 100. + .5;
  return texture(u_noiseTexture, fract(uv)).r;
}
vec2 randomGB(vec2 p) {
  vec2 uv = floor(p) / 100. + .5;
  return texture(u_noiseTexture, fract(uv)).gb;
}

vec3 voronoiShape(vec2 uv, float time) {
  vec2 i_uv = floor(uv);
  vec2 f_uv = fract(uv);
  float spreading = .25 * clamp(u_spreading, 0., 1.);
  float minDist = 1.;
  vec2 randomizer = vec2(0.);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 tileOffset = vec2(float(x), float(y));
      vec2 rand = randomGB(i_uv + tileOffset);
      vec2 cellCenter = vec2(.5 + 1e-4);
      cellCenter += spreading * cos(time + TWO_PI * rand);
      cellCenter -= .5;
      cellCenter = rotate(cellCenter, randomR(vec2(rand.x, rand.y)) + .1 * time);
      cellCenter += .5;
      float dist = length(tileOffset + cellCenter - f_uv);
      if (dist < minDist) { minDist = dist; randomizer = rand; }
    }
  }
  return vec3(minDist, randomizer);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uvc = frag / u_resolution - 0.5;
  uvc.y = -uvc.y;
  vec2 v_patternUV = uvc * u_resolution / u_pixelRatio / u_scale * 0.01;
  float pxUV = 0.01 / max(u_pixelRatio * u_scale, 1e-3);

  vec2 shape_uv = v_patternUV;
  shape_uv *= 1.5;

  const float firstFrameOffset = -10.;
  float t = u_time + firstFrameOffset;

  vec3 voronoi = voronoiShape(shape_uv, t) + 1e-4;

  float radius = .25 * clamp(u_size, 0., 1.) - .5 * clamp(u_sizeRange, 0., 1.) * voronoi[2];
  float dist = voronoi[0];
  float edgeWidth = max(1.5 * pxUV, 1e-4); // fwidth(dist) -> analytic
  float dots = 1. - smoothstep(radius - edgeWidth, radius + edgeWidth, dist);

  float shape = voronoi[1];
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

  vec3 color = gradient.rgb * dots;
  float opacity = gradient.a * dots;

  vec3 bgColor = u_colorBack.rgb * u_colorBack.a;
  color = color + bgColor * (1. - opacity);
  opacity = opacity + u_colorBack.a * (1. - opacity);

  fragColor = vec4(color, opacity);
}
