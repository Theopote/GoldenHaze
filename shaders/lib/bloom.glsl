/*
 * GoldenHaze — material-weighted bloom mask (Phase 2.9+)
 *
 * Current level: MATERIAL semantic
 *   Material Weight × Luminance Threshold
 * Better than brightness-only (snow/stone no longer auto-glow), but still
 * guesses from material ID — e.g. all bright water blooms, not just ribbons.
 *
 * Target level (Phase 3, not now): FEATURE semantic
 *   gbuffers write an effect mask (sun rim / leaf transmission / water
 *   ribbon / sparkle / emissive) into an auxiliary buffer; composite
 *   samples that mask instead of inferring from MAT_* + luma.
 * Do not expand GBuffer for this until Phase 2 is visually stable.
 */

#ifndef GOLDENHAZE_BLOOM
#define GOLDENHAZE_BLOOM

#include "/lib/gbuffer.glsl"

float materialBloomWeight(float materialId) {
    if (isSkyMaterial(materialId))              return 1.00;
    if (abs(materialId - MAT_WATER)   < 0.5) return 0.92;
    if (abs(materialId - MAT_FOLIAGE) < 0.5) return 0.72;
    if (abs(materialId - MAT_ENTITY)  < 0.5) return 0.88;
    if (abs(materialId - MAT_GLASS)   < 0.5) return 0.55;
    if (abs(materialId - MAT_GRASS)   < 0.5) return 0.38;
    if (abs(materialId - MAT_WOOD)    < 0.5) return 0.30;
    if (abs(materialId - MAT_SOIL)    < 0.5) return 0.28;
    if (abs(materialId - MAT_TERRACOTTA) < 0.5) return 0.32;
    if (abs(materialId - MAT_SNOW)    < 0.5) return 0.18;
    if (abs(materialId - MAT_STONE)   < 0.5) return 0.16;
    return 0.26;
}

float semanticBloomMask(vec3 scene, float materialId, float threshold) {
    float brightness = dot(scene, vec3(0.299, 0.587, 0.114));
    float lumaMask   = smoothstep(threshold, threshold + 0.35, brightness);
    float semantic   = materialBloomWeight(materialId);

    // Emissive entity passes (eyes, lightning) can be very bright — allow
    // a lower luma gate when semantic weight is high.
    float gate = mix(threshold + 0.08, threshold, semantic);
    lumaMask = smoothstep(gate, gate + 0.30, brightness);

    return lumaMask * semantic;
}

#endif
