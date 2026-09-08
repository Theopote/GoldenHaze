/*
 * GoldenHaze — unified material palette (Phase 2.7)
 *
 * Animation-background color anchors for terrain materials. Applied as
 * albedo tints before lighting; painterly band colors are sourced here
 * so grass / wood / stone / soil / snow share one cohesive look.
 */

#include "/lib/gbuffer.glsl"

// Map block.properties mc_Entity IDs → MAT_* constants.
float resolveTerrainMaterial(float blockId) {
    if (blockId > 0.5 && blockId < 1.5) return MAT_FOLIAGE;
    if (blockId > 1.5 && blockId < 2.5) return MAT_GRASS;
    if (blockId > 2.5 && blockId < 3.5) return MAT_WOOD;
    if (blockId > 3.5 && blockId < 4.5) return MAT_STONE;
    if (blockId > 4.5 && blockId < 5.5) return MAT_SOIL;
    if (blockId > 5.5 && blockId < 6.5) return MAT_SNOW;
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
    if (abs(materialId - MAT_WATER)   < 0.5) return vec3(0.82, 0.98, 1.02);
    if (abs(materialId - MAT_ENTITY)  < 0.5) return vec3(1.02, 0.96, 0.90);
    return vec3(1.00);
}

// Painterly lighting bands per material (shadow / mid / sun).
void materialPaletteBands(float materialId, out vec3 shadowCol,
                          out vec3 midCol, out vec3 sunCol) {
    shadowCol = vec3(0.40, 0.42, 0.56);
    midCol    = vec3(0.76, 0.74, 0.68);
    sunCol    = vec3(1.06, 0.93, 0.66);

    if (abs(materialId - MAT_FOLIAGE) < 0.5) {
        shadowCol = vec3(0.26, 0.40, 0.36);
        midCol    = vec3(0.62, 0.78, 0.42);
        sunCol    = vec3(1.04, 0.96, 0.50);
    } else if (abs(materialId - MAT_GRASS) < 0.5) {
        shadowCol = vec3(0.30, 0.44, 0.34);
        midCol    = vec3(0.66, 0.82, 0.44);
        sunCol    = vec3(1.08, 1.00, 0.52);
    } else if (abs(materialId - MAT_WOOD) < 0.5) {
        shadowCol = vec3(0.38, 0.32, 0.42);
        midCol    = vec3(0.78, 0.66, 0.52);
        sunCol    = vec3(1.10, 0.88, 0.58);
    } else if (abs(materialId - MAT_STONE) < 0.5) {
        shadowCol = vec3(0.34, 0.38, 0.50);
        midCol    = vec3(0.68, 0.70, 0.76);
        sunCol    = vec3(0.98, 0.94, 0.86);
    } else if (abs(materialId - MAT_SOIL) < 0.5) {
        shadowCol = vec3(0.42, 0.34, 0.30);
        midCol    = vec3(0.80, 0.68, 0.54);
        sunCol    = vec3(1.08, 0.90, 0.62);
    } else if (abs(materialId - MAT_SNOW) < 0.5) {
        shadowCol = vec3(0.52, 0.58, 0.72);
        midCol    = vec3(0.82, 0.86, 0.94);
        sunCol    = vec3(1.12, 1.08, 1.02);
    } else if (abs(materialId - MAT_WATER) < 0.5) {
        shadowCol = vec3(0.22, 0.42, 0.52);
        midCol    = vec3(0.48, 0.72, 0.78);
        sunCol    = vec3(0.82, 0.96, 1.08);
    } else if (abs(materialId - MAT_ENTITY) < 0.5) {
        shadowCol = vec3(0.34, 0.36, 0.48);
        midCol    = vec3(0.76, 0.72, 0.66);
        sunCol    = vec3(1.08, 0.94, 0.70);
    }
}

// Shift albedo toward palette anchor; keeps texture value structure.
vec3 applyMaterialPalette(vec3 albedo, float materialId, float strength) {
    if (strength < 0.001 || abs(materialId - MAT_DEFAULT) < 0.5) {
        return albedo;
    }

    vec3 tint = materialAlbedoTint(materialId);
    vec3 paletted = albedo * tint;

    float luma = dot(albedo, vec3(0.299, 0.587, 0.114));
    paletted = mix(vec3(luma), paletted, 1.12);

    return mix(albedo, paletted, strength);
}
