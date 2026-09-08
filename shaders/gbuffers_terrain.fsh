/*
 * gbuffers_terrain — world geometry fragment shader
 * Painterly band lighting (lib/painterly.glsl) + GBuffer output.
 */
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
varying float blockId;

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
    if (albedo.a < 0.1) discard;

    vec3 vanillaLight = texture2D(lightmap, lmcoord).rgb;

    float materialId = MAT_DEFAULT;
    if (blockId > 0.5 && blockId < 1.5) {
        materialId = MAT_FOLIAGE;
    }

    vec3 litColor = shadePainterly(albedo.rgb, normal, sunPosition, lmcoord,
                                   vanillaLight, materialId, rainStrength,
                                   PAINTERLY_STRENGTH, feetPlayerPos,
                                   SHADOW_STRENGTH, SHADOW_SOFTNESS);

    if (materialId == MAT_FOLIAGE) {
        vec2 sp  = worldPos.xz * 2.5 + worldPos.yy * 1.7;
        float n1 = vnoise(sp * 3.0 + frameTimeCounter * vec2(0.9, 0.4));
        float n2 = vnoise(sp * 5.0 - frameTimeCounter * vec2(0.6, 0.8));
        float fleck = smoothstep(0.78, 0.95, n1 * n2 * 2.0);
        float sparkle = fleck * lmcoord.y * SHIMMER_STRENGTH;
        litColor += vec3(1.00, 0.85, 0.55) * sparkle * 0.6;
    }

    gl_FragData[0] = vec4(litColor, albedo.a);
    gl_FragData[1] = packGBuffer(normal, materialId);
}
