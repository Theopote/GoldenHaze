/*
 * gbuffers_water — stylized water (Phase 2.5)
 * Palette body color + horizontal sun-band highlights.
 */
#version 120

#include "/lib/painterly.glsl"
#include "/lib/water.glsl"

#define PAINTERLY_STRENGTH 1.0 // [0.00 0.25 0.50 0.75 1.00]
#define WATER_STRENGTH     1.0 // [0.00 0.25 0.50 0.75 1.00]
#define WATER_DIST_NEAR    4.0 // [2.0 4.0 8.0 12.0 16.0]
#define WATER_DIST_FAR    40.0 // [24.0 40.0 64.0 96.0 128.0]
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
varying vec3 viewDir;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;

    vec3 vanillaLight = texture2D(lightmap, lmcoord).rgb;
    vec3 litColor = shadePainterly(albedo.rgb, normal, sunPosition, lmcoord,
                                   vanillaLight, MAT_WATER, rainStrength,
                                   PAINTERLY_STRENGTH, feetPlayerPos,
                                   SHADOW_STRENGTH, SHADOW_SOFTNESS);

    litColor = applyWaterShading(albedo.rgb, litColor, worldPos, feetPlayerPos,
                                 normal, viewDir, sunPosition, lmcoord,
                                 rainStrength, frameTimeCounter,
                                 WATER_STRENGTH, SHIMMER_STRENGTH,
                                 WATER_DIST_NEAR, WATER_DIST_FAR);

    gl_FragData[0] = vec4(litColor, albedo.a);
    gl_FragData[1] = packGBuffer(normal, MAT_WATER);
}
