#version 460 core
// The loading screen's night: a crimson nebula drifting slowly behind the
// mask, brighter towards the centre, with a soft vignette. One pass on the
// GPU, four octaves of noise. uIntensity fades it in from the splash's
// plain night (0) to the full sky (1).

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  // Centred and aspect-correct: the same nebula on any screen.
  vec2 p = (frag - 0.5 * uSize) / uSize.y;
  float t = uTime * 0.04;

  // Domain warping: the noise bends itself, like smoke.
  vec2 q = vec2(fbm(p * 2.2 + t), fbm(p * 2.2 - t + 3.1));
  float n = fbm(p * 1.6 + q * 1.4 + vec2(t * 0.6, -t * 0.4));

  float r = length(p);
  float halo = smoothstep(0.75, 0.0, r);
  float nebula = pow(n, 1.8) * halo;

  vec3 night = vec3(0.094, 0.106, 0.133);   // AppColors.splash, #181B22
  vec3 crimson = vec3(0.55, 0.03, 0.05);
  vec3 col = night + crimson * nebula * 0.9 * uIntensity;
  col *= mix(1.0, 0.82, smoothstep(0.35, 1.1, r) * uIntensity);

  fragColor = vec4(col, 1.0);
}
