#version 460 core
#include <flutter/runtime_effect.glsl>

// Port of beUI `components/agents/voice-orb/renderer.ts` FRAGMENT.
// WebGL gl_FragCoord is origin-bottom-left; FlutterFragCoord is origin-top-left
// so Y is flipped before the source body. gl_FragColor → fragColor.
// Uniform order is the source's: resolution, time, activity, base, light, dark.

uniform vec2 u_resolution; // 0,1
uniform float u_time;      // 2
uniform float u_activity;  // 3
uniform vec3 u_base;       // 4..6
uniform vec3 u_light;      // 7..9
uniform vec3 u_dark;       // 10..12

out vec4 fragColor;

float hash(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
      mix(
          mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
          mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x),
          f.y),
      mix(
          mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
          mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x),
          f.y),
      f.z);
}

float fbm(vec3 p) {
  return noise(p) * 0.57 + noise(p * 2.03 + 7.2) * 0.28 +
         noise(p * 4.07 + 3.1) * 0.15;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  frag.y = u_resolution.y - frag.y;
  vec2 p = (frag * 2.0 - u_resolution) / min(u_resolution.x, u_resolution.y);
  float t = u_time * 0.38;
  float angle = atan(p.y, p.x);
  float breath = sin(u_time * 1.4) * 0.008;
  float ripple = sin(angle * 3.0 + t * 2.1) * 0.55 +
                 sin(angle * 5.0 - t * 1.7) * 0.30 + sin(angle * 2.0 + t) * 0.15;
  p /= 0.91 + breath + u_activity * 0.025 +
       ripple * (0.004 + u_activity * 0.024);
  float r2 = dot(p, p);
  float aa = 3.0 / min(u_resolution.x, u_resolution.y);
  float alpha = 1.0 - smoothstep(1.0 - aa, 1.0, r2);
  if (alpha <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  vec3 normal = vec3(p, sqrt(max(0.0, 1.0 - r2)));
  vec3 flow = vec3(normal.xy * 1.65, normal.z * 1.4);
  flow.xy += vec2(sin(normal.y * 2.6 + t), cos(normal.x * 2.3 - t * 0.8)) *
             (0.25 + u_activity * 0.22);
  vec3 warp = vec3(noise(flow + vec3(0.0, t, t * 0.3)),
                   noise(flow + vec3(4.7, -t * 0.7, t)),
                   noise(flow + vec3(t * 0.5, 9.2, -t))) -
              0.5;
  float pigment = fbm(flow + warp * 1.4 + vec3(t * 0.3, -t * 0.2, t * 0.4));
  float fold = normal.x * 0.50 + normal.y * 0.32 +
               sin(normal.y * 2.6 - t) * 0.30 + (pigment - 0.5) * 0.65;
  float shadow = smoothstep(-0.30, 0.42, fold);
  vec3 color = mix(u_dark, u_base, shadow);
  color = mix(color, u_light, smoothstep(0.40, 0.82, pigment) * 0.34);
  float diffuse = max(0.0, dot(normal, normalize(vec3(-0.4, 0.65, 1.0))));
  color *= 0.64 + 0.46 * diffuse;
  float shine = exp(-pow((fold + 0.06) * 8.0, 2.0)) * pow(normal.z, 0.65);
  float innerLight = exp(-pow((fold - 0.28) * 4.0, 2.0)) * normal.z;
  color = mix(color, u_light, innerLight * (0.18 + u_activity * 0.16));
  color = mix(color, mix(u_light, vec3(1.0), 0.55), shine * 0.78);
  float gleam =
      pow(max(0.0, dot(normal, normalize(vec3(-0.45, 0.55, 1.0)))), 24.0);
  color += gleam * 0.16;
  float rim = pow(1.0 - normal.z, 3.0);
  color = mix(color, u_light, rim * (0.36 + 0.25 * max(0.0, -normal.x)));
  float grain = hash(vec3(frag, 1.0)) - 0.5;
  color += grain * 0.032;
  fragColor = vec4(clamp(color, 0.0, 1.0) * alpha, alpha);
}
