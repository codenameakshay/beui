#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of @paper-design/shaders `colorPanelsFragmentShader` (animated).
// Deviations (shared — see beui_mesh_gradient.frag): v_objectUV inlined;
// MAX_COLORS 8; `uniform bool u_edges` -> float (compared > 0.5); integer % ->
// float mod; the local premultipliedColors[] array + dynamic indexing are
// replaced by a constant-index selector getColor(). No texture.

#define TWO_PI 6.28318530718
#define PI 3.14159265358979323846
#define MAX_COLORS 8

uniform vec2 u_resolution;   // 0,1
uniform float u_time;        // 2
uniform float u_pixelRatio;  // 3
uniform float u_scale;       // 4

uniform vec4 u_colors[MAX_COLORS]; // 5..36
uniform float u_colorsCount;       // 37
uniform vec4 u_colorBack;          // 38..41
uniform float u_density;           // 42
uniform float u_angle1;            // 43
uniform float u_angle2;            // 44
uniform float u_length;            // 45
uniform float u_edges;             // 46 (bool as 0/1)
uniform float u_blur;              // 47
uniform float u_fadeIn;            // 48
uniform float u_fadeOut;           // 49
uniform float u_gradient;          // 50

out vec4 fragColor;

const float zLimit = .5;

vec4 getColor(int idx) {
  vec4 c = u_colors[0];
  for (int k = 0; k < MAX_COLORS; k++) {
    if (k == idx) c = u_colors[k];
  }
  c.rgb *= c.a;
  return c;
}

vec2 getPanel(float angle, vec2 uv, float invLength, float aa) {
  float sinA = sin(angle);
  float cosA = cos(angle);
  float denom = sinA - uv.y * cosA;
  if (abs(denom) < .01) return vec2(0.);
  float z = uv.y / denom;
  if (z <= 0. || z > zLimit) return vec2(0.);
  float zRatio = z / zLimit;
  float panelMap = 1. - zRatio;
  float x = uv.x * (cosA * z + 1.) * invLength;
  float zOffset = zRatio - .5;
  float left = -.5 + zOffset * u_angle1;
  float right = .5 - zOffset * u_angle2;
  float blurX = aa + 2. * panelMap * u_blur;
  float leftEdge1 = left - blurX;
  float leftEdge2 = left + .25 * blurX;
  float rightEdge1 = right - .25 * blurX;
  float rightEdge2 = right + blurX;
  float panel = smoothstep(leftEdge1, leftEdge2, x) * (1.0 - smoothstep(rightEdge1, rightEdge2, x));
  panel *= mix(0., panel, smoothstep(0., .01 / max(u_scale, 1e-6), panelMap));
  float midScreen = abs(sinA);
  if (u_edges > 0.5) {
    panelMap = mix(.99, panelMap, panel * clamp(panelMap / (.15 * (1. - pow(midScreen, .1))), 0.0, 1.0));
  } else if (midScreen < .07) {
    panel *= (midScreen * 15.);
  }
  return vec2(panel, panelMap);
}

vec4 blendColor(vec4 colorA, float panelMask, float panelMap) {
  float fade = 1. - smoothstep(.97 - .97 * u_fadeIn, 1., panelMap);
  fade *= smoothstep(-.2 * (1. - u_fadeOut), u_fadeOut, panelMap);
  vec3 blendedRGB = mix(vec3(0.), colorA.rgb, fade);
  float blendedAlpha = mix(0., colorA.a, fade);
  return vec4(blendedRGB, blendedAlpha) * panelMask;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 ndc = frag / u_resolution - 0.5;
  ndc.y = -ndc.y;
  float minDim = min(u_resolution.x, u_resolution.y);
  vec2 v_objectUV = ndc * (u_resolution / minDim) / u_scale;

  vec2 uv = v_objectUV;
  uv *= 1.25;

  float t = .02 * u_time;
  t = fract(t);
  bool reverseTime = (t < 0.5);

  vec3 color = vec3(0.);
  float opacity = 0.;

  float aa = .005 / u_scale;
  int colorsCount = int(u_colorsCount);
  float fColorsCount = max(1.0, float(colorsCount));
  float invLength = 1.5 / max(u_length, .001);

  int panelsNumber = 12;
  float densityNormalizer = 1.;
  if (colorsCount == 4) { panelsNumber = 16; densityNormalizer = 1.34; }
  else if (colorsCount == 5) { panelsNumber = 20; densityNormalizer = 1.67; }
  else if (colorsCount == 7) { panelsNumber = 14; densityNormalizer = 1.17; }
  float fPanelsNumber = float(panelsNumber);
  float panelGrad = 1. - clamp(u_gradient, 0., 1.);

  for (int set = 0; set < 2; set++) {
    bool isForward = (set == 0 && !reverseTime) || (set == 1 && reverseTime);
    if (!isForward) continue;

    for (int i = 0; i <= 20; i++) {
      if (i >= panelsNumber) break;
      int idx = panelsNumber - 1 - i;
      float offset = float(idx) / fPanelsNumber;
      if (set == 1) offset += .5;
      float densityFract = densityNormalizer * fract(t + offset);
      float angleNorm = densityFract / u_density;
      if (densityFract >= .5 || angleNorm >= .3) continue;
      float smoothDensity = clamp((.5 - densityFract) / .1, 0., 1.) * clamp(densityFract / .01, 0., 1.);
      float smoothAngle = clamp((.3 - angleNorm) / .05, 0., 1.);
      if (smoothDensity * smoothAngle < .001) continue;
      if (angleNorm > .5) angleNorm = 0.5;
      vec2 panel = getPanel(angleNorm * TWO_PI + PI, uv, invLength, aa);
      if (panel[0] <= .001) continue;
      float panelMask = panel[0] * smoothDensity * smoothAngle;
      float panelMap = panel[1];
      int colorIdx = int(mod(float(idx), fColorsCount));
      int nextColorIdx = int(mod(float(idx + 1), fColorsCount));
      vec4 colorA = getColor(colorIdx);
      vec4 colorB = getColor(nextColorIdx);
      colorA = mix(colorA, colorB, max(0., smoothstep(.0, .45, panelMap) - panelGrad));
      vec4 blended = blendColor(colorA, panelMask, panelMap);
      color = blended.rgb + color * (1. - blended.a);
      opacity = blended.a + opacity * (1. - blended.a);
    }

    for (int i = 0; i <= 20; i++) {
      if (i >= panelsNumber) break;
      int idx = panelsNumber - 1 - i;
      float offset = float(idx) / fPanelsNumber;
      if (set == 0) offset += .5;
      float densityFract = densityNormalizer * fract(-t + offset);
      float angleNorm = -densityFract / u_density;
      if (densityFract >= .5 || angleNorm < -.3) continue;
      float smoothDensity = clamp((.5 - densityFract) / .1, 0., 1.) * clamp(densityFract / .01, 0., 1.);
      float smoothAngle = clamp((angleNorm + .3) / .05, 0., 1.);
      if (smoothDensity * smoothAngle < .001) continue;
      vec2 panel = getPanel(angleNorm * TWO_PI + PI, uv, invLength, aa);
      float panelMask = panel[0] * smoothDensity * smoothAngle;
      if (panelMask <= .001) continue;
      float panelMap = panel[1];
      int m = int(mod(float(idx), fColorsCount));
      int colorIdx = int(mod(float(colorsCount - m), fColorsCount));
      int nextColorIdx = int(mod(float(colorIdx + 1), fColorsCount));
      vec4 colorA = getColor(colorIdx);
      vec4 colorB = getColor(nextColorIdx);
      colorA = mix(colorA, colorB, max(0., smoothstep(.0, .45, panelMap) - panelGrad));
      vec4 blended = blendColor(colorA, panelMask, panelMap);
      color = blended.rgb + color * (1. - blended.a);
      opacity = blended.a + opacity * (1. - blended.a);
    }
  }

  vec3 bgColor = u_colorBack.rgb * u_colorBack.a;
  color = color + bgColor * (1.0 - opacity);
  opacity = opacity + u_colorBack.a * (1.0 - opacity);

  color += 1. / 256. * (fract(sin(dot(.014 * frag, vec2(12.9898, 78.233))) * 43758.5453123) - .5);

  fragColor = vec4(color, opacity);
}
