#version 120

#include "/lib/painterly.glsl"

#define PAINTERLY_STRENGTH 1.0 // [0.00 0.25 0.50 0.75 1.00]
#define SHADOW_STRENGTH    1.0 // [0.00 0.50 0.75 1.00]
#define SHADOW_SOFTNESS    2.5 // [1.0 1.5 2.0 2.5 3.5 5.0]
#define SHIMMER_STRENGTH   1.0 // [0.00 0.30 0.60 1.00 1.50 2.00]

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform float frameTimeCounter;
uniform float rainStrength;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 worldPos;
varying vec3 feetPlayerPos;
varying vec3 normal;

/* DRAWBUFFERS:01 */

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),               hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;

    vec3 vanillaLight = texture2D(lightmap, lmcoord).rgb;
    vec3 litColor = shadePainterly(albedo.rgb, normal, sunPosition, lmcoord,
                                   vanillaLight, MAT_WATER, rainStrength,
                                   PAINTERLY_STRENGTH, feetPlayerPos,
                                   SHADOW_STRENGTH, SHADOW_SOFTNESS);

    vec2 wp  = worldPos.xz;
    float n1 = vnoise(wp * 1.6 + frameTimeCounter * vec2(0.35, 0.15));
    float n2 = vnoise(wp * 2.3 - frameTimeCounter * vec2(0.22, 0.40));
    float glint = smoothstep(0.72, 0.92, n1 * n2 * 2.0);
    float sparkle = glint * lmcoord.y * SHIMMER_STRENGTH;
    litColor += vec3(1.00, 0.88, 0.60) * sparkle * 0.8;

    gl_FragData[0] = vec4(litColor, albedo.a);
    gl_FragData[1] = packGBuffer(normal, MAT_WATER);
}
