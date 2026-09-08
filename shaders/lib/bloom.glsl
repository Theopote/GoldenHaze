/*
 * GoldenHaze — material-weighted bloom mask (Phase 2.9+)
 *
 * Current level: MATERIAL semantic
 *   Material Weight × Luminance Threshold
 * Better than brightness-only (snow/stone no longer auto-glow), but still
 * guesses from material ID — e.g. bright water still blooms as a body,
 * not only sun ribbons.
 *
 * MAT_ENTITY  = ordinary living/props (low bloom)
 * MAT_EMISSIVE = spider eyes / lightning / true glow (full bloom)
 *
 * Target level (Phase 3, not now): FEATURE semantic mask buffer.
 * Do not expand GBuffer for that until Phase 2 is visually stable.
 */

#ifndef GOLDENHAZE_BLOOM
#define GOLDENHAZE_BLOOM

#include "/lib/gbuffer.glsl"

float materialBloomWeight(float materialId) {
    if (isSkyMaterial(materialId))                 return 1.00;
    if (abs(materialId - MAT_EMISSIVE) < 0.5)    return 1.00;
    if (abs(materialId - MAT_WATER)    < 0.5)    return 0.60;
    if (abs(materialId - MAT_FOLIAGE)  < 0.5)    return 0.58;
    if (abs(materialId - MAT_ENTITY)   < 0.5)    return 0.22;
    if (abs(materialId - MAT_GLASS)    < 0.5)    return 0.45;
    if (abs(materialId - MAT_GRASS)    < 0.5)    return 0.32;
    if (abs(materialId - MAT_WOOD)     < 0.5)    return 0.28;
    if (abs(materialId - MAT_SOIL)     < 0.5)    return 0.26;
    if (abs(materialId - MAT_TERRACOTTA) < 0.5)  return 0.30;
    if (abs(materialId - MAT_SNOW)     < 0.5)    return 0.16;
    if (abs(materialId - MAT_STONE)    < 0.5)    return 0.14;
    return 0.24;
}

float semanticBloomMask(vec3 scene, float materialId, float threshold) {
    float brightness = dot(scene, vec3(0.299, 0.587, 0.114));
    float semantic   = materialBloomWeight(materialId);

    // Emissive materials get a lower luma gate so dim glow still blooms.
    float gate = mix(threshold + 0.08, threshold * 0.55, semantic);
    if (abs(materialId - MAT_EMISSIVE) < 0.5) {
        gate = threshold * 0.35;
    }
    float lumaMask = smoothstep(gate, gate + 0.30, brightness);

    return lumaMask * semantic;
}

#endif
