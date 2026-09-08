/*
 * gbuffers_hand_water — translucent held items (water bucket, potions, etc.)
 */
#version 120

#include "/lib/gbuffers_pass.glsl"
#include "/lib/water.glsl"

#define PAINTERLY_STRENGTH 1.0 // [0.00 0.25 0.50 0.75 1.00]
#define WATER_STRENGTH     0.85 // [0.00 0.25 0.50 0.75 1.00]
#define WATER_DIST_NEAR    2.0 // [1.0 2.0 4.0 8.0]
#define WATER_DIST_FAR    16.0 // [8.0 16.0 24.0 40.0]
#define SHADOW_STRENGTH    0.0
#define SHADOW_SOFTNESS    2.5 // [1.0 1.5 2.0 2.5 3.5 5.0]

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform float rainStrength;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 normal;
varying vec3 feetPlayerPos;
varying vec3 worldPos;
varying vec3 viewDir;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.02) discard;

    vec3 vanillaLight = texture2D(lightmap, lmcoord).rgb;
    vec3 baseAlbedo   = applyMaterialPalette(albedo.rgb, MAT_WATER, WATER_STRENGTH);
    vec3 litColor     = shadePainterly(baseAlbedo, normal, sunPosition, lmcoord,
                                       vanillaLight, MAT_WATER, rainStrength,
                                       PAINTERLY_STRENGTH, feetPlayerPos,
                                       SHADOW_STRENGTH, SHADOW_SOFTNESS);

    float skyVis = smoothstep(0.02, 0.28, lmcoord.y);
    litColor = applyWaterShading(albedo.rgb, litColor, worldPos, feetPlayerPos,
                                   normal, viewDir, sunPosition, lmcoord,
                                   rainStrength, 0.0, WATER_STRENGTH * 0.5,
                                   WATER_DIST_NEAR, WATER_DIST_FAR);

    gl_FragData[0] = vec4(litColor, albedo.a);
    gl_FragData[1] = packGBuffer(normal, MAT_WATER);
}
