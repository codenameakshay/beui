#version 460 core
#include <flutter/runtime_effect.glsl>

// Toolchain probe for BeuiShaderBackground. Confirms the flutter tool compiles
// a package .frag, that it loads via FragmentProgram.fromAsset, and that
// uniforms can be set and the shader painted. NOTE (feasibility, verified):
// Impeller's shader compiler rejects `fwidth`/derivatives — shaders that use
// them for anti-aliasing must switch to an analytic AA width (e.g. derived from
// u_resolution) when ported.
uniform vec2 u_resolution;
uniform float u_time;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_resolution;
  fragColor = vec4(uv.x, uv.y, 0.5 + 0.5 * sin(u_time), 1.0);
}
