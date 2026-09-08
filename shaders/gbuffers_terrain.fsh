/*
 * gbuffers_terrain — world geometry fragment shader
 * Unified material palette + painterly lighting + Foliage 2.0 for leaves.
 */
#version 120

#include "/lib/painterly.glsl"
#include "/lib/foliage.glsl"

#define PAINTERLY_STRENGTH 1.0 // [0.00 0.25 0.50 0.75 1.00]
#define PALETTE_STRENGTH   1.0 // [0.00 0.25 0.50 0.75 1.00]
#define FOLIAGE_STRENGTH   1.0 // [0.00 0.25 0.50 0.75 1.00]
#define SHADOW_STRENGTH    1.0 // [0.00 0.50 0.75 1.00]
#define SHADOW_SOFTNESS    2.5 // [1.0 1.5 2.0 2.5 3.5 5.0]
#define SHIMMER_STRENGTH   0.75 // [0.00 0.30 0.60 0.75 1.00 1.50 2.00]

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
varying vec3 worldNormal;
varying float blockId;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.1) discard;

    float materialId = resolveTerrainMaterial(blockId);
    vec3 baseAlbedo = applyMaterialPalette(albedo.rgb, materialId, PALETTE_STRENGTH);

    vec3 vanillaLight = texture2D(lightmap, lmcoord).rgb;
    vec3 litColor = shadePainterly(baseAlbedo, normal, worldNormal, sunPosition,
                                   lmcoord, vanillaLight, materialId, rainStrength,
                                   PAINTERLY_STRENGTH, feetPlayerPos,
                                   SHADOW_STRENGTH, SHADOW_SOFTNESS);

    if (materialId == MAT_FOLIAGE) {
        float skyVis;
        float blockVis;
        lightmapVisibility(lmcoord, skyVis, blockVis);

        litColor = applyFoliageShading(baseAlbedo, litColor, worldPos, normal,
                                       worldNormal, sunPosition, lmcoord, skyVis,
                                       frameTimeCounter, FOLIAGE_STRENGTH,
                                       SHIMMER_STRENGTH);
    }

    gl_FragData[0] = vec4(litColor, albedo.a);
    gl_FragData[1] = packGBuffer(normal, materialId);
}
