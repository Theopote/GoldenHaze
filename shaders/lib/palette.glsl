/*
 * GoldenHaze — unified material palette (Phase 2.7)
 *
 * Animation-background color anchors for terrain materials. Applied as
 * albedo tints before lighting; painterly band colors are sourced here
 * so grass / wood / stone / soil / snow share one cohesive look.
 */

#ifndef GOLDENHAZE_PALETTE
#define GOLDENHAZE_PALETTE

#include "/lib/gbuffer.glsl"

// Soft chroma push toward palette anchors. Keep near 1.0 to avoid candy colors
// once warmGrade / bloom also run in final.
#define PALETTE_CHROMA 1.05 // [1.00 1.03 1.05 1.08 1.12]

// Map block.properties mc_Entity IDs → MAT_* constants.
float resolveTerrainMaterial(float blockId) {
    if (blockId > 0.5 && blockId < 1.5) return MAT_FOLIAGE;
    if (blockId > 1.5 && blockId < 2.5) return MAT_GRASS;
    if (blockId > 2.5 && blockId < 3.5) return MAT_WOOD;
    if (blockId > 3.5 && blockId < 4.5) return MAT_STONE;
    if (blockId > 4.5 && blockId < 5.5) return MAT_SOIL;
    if (blockId > 5.5 && blockId < 6.5) return MAT_SNOW;
    if (blockId > 6.5 && blockId < 7.5) return MAT_TERRACOTTA;
    if (blockId > 7.5 && blockId < 8.5) return MAT_GLASS;
    return MAT_DEFAULT;
}

// Albedo multiply tint — nudges texture chroma toward the palette anchor.
vec3 materialAlbedoTint(float materialId) {
    if (abs(materialId - MAT_FOLIAGE) < 0.5) return vec3(0.90, 1.06, 0.70);
    if (abs(materialId - MAT_GRASS)   < 0.5) return vec3(0.88, 1.10, 0.68);
    if (abs(materialId - MAT_WOOD)    < 0.5) return vec3(1.06, 0.90, 0.74);
    if (abs(materialId - MAT_STONE)   < 0.5) return vec3(0.86, 0.90, 1.00);
    if (abs(materialId - MAT_SOIL)    < 0.5) return vec3(1.10, 0.94, 0.78);
    if (abs(materialId - MAT_SNOW)    < 0.5) return vec3(0.94, 0.98, 1.14);
    if (abs(materialId - MAT_TERRACOTTA) < 0.5) return vec3(1.08, 0.78, 0.58);
    if (abs(materialId - MAT_GLASS)   < 0.5) return vec3(0.88, 0.96, 1.04);
    if (abs(materialId - MAT_WATER)   < 0.5) return vec3(0.82, 0.98, 1.02);
    if (abs(materialId - MAT_ENTITY)  < 0.5) return vec3(1.02, 0.96, 0.90);
    return vec3(1.00);
}

// Painterly lighting bands per material (shadow / mid / sun).
void materialPaletteBands(float materialId, out vec3 toneLo,
                          out vec3 toneMd, out vec3 toneHi) {
    toneLo = vec3(0.40, 0.42, 0.56);
    toneMd = vec3(0.76, 0.74, 0.68);
    toneHi = vec3(1.06, 0.93, 0.66);

    if (abs(materialId - MAT_FOLIAGE) < 0.5) {
        toneLo = vec3(0.26, 0.40, 0.36);
        toneMd = vec3(0.62, 0.78, 0.42);
        toneHi = vec3(1.04, 0.96, 0.50);
    } else if (abs(materialId - MAT_GRASS) < 0.5) {
        toneLo = vec3(0.30, 0.44, 0.34);
        toneMd = vec3(0.66, 0.82, 0.44);
        toneHi = vec3(1.08, 1.00, 0.52);
    } else if (abs(materialId - MAT_WOOD) < 0.5) {
        toneLo = vec3(0.38, 0.32, 0.42);
        toneMd = vec3(0.78, 0.66, 0.52);
        toneHi = vec3(1.10, 0.88, 0.58);
    } else if (abs(materialId - MAT_STONE) < 0.5) {
        toneLo = vec3(0.34, 0.38, 0.50);
        toneMd = vec3(0.68, 0.70, 0.76);
        toneHi = vec3(0.98, 0.94, 0.86);
    } else if (abs(materialId - MAT_SOIL) < 0.5) {
        toneLo = vec3(0.42, 0.34, 0.30);
        toneMd = vec3(0.80, 0.68, 0.54);
        toneHi = vec3(1.08, 0.90, 0.62);
    } else if (abs(materialId - MAT_SNOW) < 0.5) {
        toneLo = vec3(0.52, 0.58, 0.72);
        toneMd = vec3(0.82, 0.86, 0.94);
        toneHi = vec3(1.12, 1.08, 1.02);
    } else if (abs(materialId - MAT_TERRACOTTA) < 0.5) {
        toneLo = vec3(0.42, 0.30, 0.26);
        toneMd = vec3(0.82, 0.58, 0.42);
        toneHi = vec3(1.10, 0.78, 0.52);
    } else if (abs(materialId - MAT_GLASS) < 0.5) {
        toneLo = vec3(0.38, 0.48, 0.58);
        toneMd = vec3(0.72, 0.82, 0.92);
        toneHi = vec3(1.04, 1.02, 0.98);
    } else if (abs(materialId - MAT_WATER) < 0.5) {
        toneLo = vec3(0.22, 0.42, 0.52);
        toneMd = vec3(0.48, 0.72, 0.78);
        toneHi = vec3(0.82, 0.96, 1.08);
    } else if (abs(materialId - MAT_ENTITY) < 0.5) {
        toneLo = vec3(0.34, 0.36, 0.48);
        toneMd = vec3(0.76, 0.72, 0.66);
        toneHi = vec3(1.08, 0.94, 0.70);
    }
}

// Shift albedo toward palette anchor; keeps texture value structure.
vec3 applyMaterialPalette(vec3 albedo, float materialId, float strength) {
    if (strength < 0.001 || abs(materialId - MAT_DEFAULT) < 0.5) {
        return albedo;
    }

    vec3 albedoMul = materialAlbedoTint(materialId);
    vec3 paletted = albedo * albedoMul;

    float luma = dot(albedo, vec3(0.299, 0.587, 0.114));
    paletted = mix(vec3(luma), paletted, PALETTE_CHROMA);

    return mix(albedo, paletted, strength);
}

#endif
