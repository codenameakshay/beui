#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `metaballsFragmentShader` (animated, texture).
// Deviations (shared — see beui_voronoi.frag): v_objectUV inlined; MAX_COLORS 8;
// integer % -> float mod; dynamic u_colors[safeIndex] -> constant-index loop;
// fwidth(totalShape) -> analytic objectUV AA; randomR inlined; banding fix uses
// FlutterFragCoord.

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846
#define MAX_COLORS 8
#define MAX_BALLS 20

uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

uniform sampler2D u_noiseTexture; // sampler 0

uniform vec4 u_colorBack;          // 5..8
uniform vec4 u_colors[MAX_COLORS]; // 9..40
uniform float u_colorsCount;       // 41
uniform float u_size;              // 42
uniform float u_sizeRange;         // 43
uniform float u_count;             // 44

out vec4 fragColor;

float randomR(vec2 p) {
  vec2 uv = floor(p) / 100. + .5;
  return texture(u_noiseTexture, fract(uv)).r;
}
float noise(float x) {
  float i = floor(x);
  float f = fract(x);
  float u = f * f * (3.0 - 2.0 * f);
  return mix(randomR(vec2(i, 0.0)), randomR(vec2(i + 1.0, 0.0)), u);
}
float getBallShape(vec2 uv, vec2 c, float p) {
  float s = .5 * length(uv - c);
  s = 1. - clamp(s, 0., 1.);
  s = pow(s, p);
  return s;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 ndc = frag / u_resolution - 0.5;
  ndc.y = -ndc.y;
  float minDim = min(u_resolution.x, u_resolution.y);
  vec2 v_objectUV = ndc * (u_resolution / minDim) / u_scale;
  float aaPx = 1.0 / max(minDim * u_scale, 1e-3);

  vec2 shape_uv = v_objectUV;
  shape_uv += .5;

  const float firstFrameOffset = 2503.4;
  float t = .2 * (u_time + firstFrameOffset);

  vec3 totalColor = vec3(0.);
  float totalShape = 0.;
  float totalOpacity = 0.;

  for (int i = 0; i < MAX_BALLS; i++) {
    if (i >= int(ceil(u_count))) break;
    float idxFract = float(i) / float(MAX_BALLS);
    float angle = TWO_PI * idxFract;
    float speed = 1. - .2 * idxFract;
    float noiseX = noise(angle * 10. + float(i) + t * speed);
    float noiseY = noise(angle * 20. + float(i) - t * speed);
    vec2 pos = vec2(.5) + 1e-4 + .9 * (vec2(noiseX, noiseY) - .5);

    int safeIndex = int(mod(float(i), max(1.0, floor(u_colorsCount + 0.5))));
    vec4 ballColor = u_colors[0];
    for (int k = 0; k < MAX_COLORS; k++) {
      if (k == safeIndex) ballColor = u_colors[k];
    }
    ballColor.rgb *= ballColor.a;

    float sizeFrac = 1.;
    if (float(i) > floor(u_count - 1.)) sizeFrac *= fract(u_count);

    float shape = getBallShape(shape_uv, pos, 45. - 30. * u_size * sizeFrac);
    shape *= pow(u_size, .2);
    shape = smoothstep(0., 1., shape);

    totalColor += ballColor.rgb * shape;
    totalShape += shape;
    totalOpacity += ballColor.a * shape;
  }

  totalColor /= max(totalShape, 1e-4);
  totalOpacity /= max(totalShape, 1e-4);

  float edge_width = max(4.0 * aaPx, 1e-3); // fwidth(totalShape) -> analytic
  float finalShape = smoothstep(.4, .4 + edge_width, totalShape);

  vec3 color = totalColor * finalShape;
  float opacity = totalOpacity * finalShape;

  vec3 bgColor = u_colorBack.rgb * u_colorBack.a;
  color = color + bgColor * (1. - opacity);
  opacity = opacity + u_colorBack.a * (1. - opacity);

  color += 1. / 256. * (fract(sin(dot(.014 * frag, vec2(12.9898, 78.233))) * 43758.5453123) - .5);

  fragColor = vec4(color, opacity);
}
