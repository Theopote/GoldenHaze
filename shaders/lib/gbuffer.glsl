/*
 * GoldenHaze GBuffer packing — written to colortex1 by all gbuffers passes.
 *
 * RGB : view-space surface normal, encoded to [0, 1]
 * Alpha : material / block ID (integer 0–255 stored as id / 255.0)
 *
 * Phase 2.2 reads this in gbuffers for painterly lighting; final uses
 * material ID to skip sky in atmospheric perspective.
 */

#define MAT_DEFAULT 0.0
#define MAT_FOLIAGE 1.0
#define MAT_WATER   2.0
#define MAT_SKY     3.0
#define MAT_GRASS   4.0
#define MAT_WOOD    5.0
#define MAT_STONE   6.0
#define MAT_SOIL    7.0
#define MAT_SNOW    8.0
#define MAT_ENTITY     9.0
#define MAT_TERRACOTTA 10.0
#define MAT_GLASS      11.0

vec3 encodeNormal(vec3 n) {
    return normalize(n) * 0.5 + 0.5;
}

vec3 decodeNormal(vec3 enc) {
    return normalize(enc * 2.0 - 1.0);
}

vec4 packGBuffer(vec3 viewNormal, float materialId) {
    return vec4(encodeNormal(viewNormal), materialId / 255.0);
}
