/*
 * GoldenHaze — debug views (Phase 2 infrastructure)
 *
 * DEBUG_VIEW in final.fsh:
 *   0 = final image
 *   1 = GBuffer normals
 *   2 = depth
 *   3 = material ID
 *   4 = NdotL (sun-facing)
 *   5 = sky-light proxy (outdoor fill estimate)
 *   6 = block-light proxy (torch / cave estimate)
 *   7 = atmosphere haze
 *   8 = bloom mask (colortex2 pre-grade)
 */

#ifndef GOLDENHAZE_DEBUG
#define GOLDENHAZE_DEBUG

#include "/lib/gbuffer.glsl"

vec3 debugMaterialColor(float materialId) {
    if (isSkyMaterial(materialId))              return vec3(0.20, 0.55, 1.00);
    if (abs(materialId - MAT_FOLIAGE) < 0.5)    return vec3(0.20, 0.90, 0.25);
    if (abs(materialId - MAT_WATER)   < 0.5)    return vec3(0.10, 0.75, 0.95);
    if (abs(materialId - MAT_GRASS)   < 0.5)    return vec3(0.45, 0.95, 0.30);
    if (abs(materialId - MAT_WOOD)    < 0.5)    return vec3(0.85, 0.55, 0.20);
    if (abs(materialId - MAT_STONE)   < 0.5)    return vec3(0.55, 0.58, 0.65);
    if (abs(materialId - MAT_SOIL)    < 0.5)    return vec3(0.75, 0.45, 0.22);
    if (abs(materialId - MAT_SNOW)    < 0.5)    return vec3(0.90, 0.95, 1.00);
    if (abs(materialId - MAT_TERRACOTTA) < 0.5) return vec3(0.92, 0.42, 0.28);
    if (abs(materialId - MAT_GLASS)   < 0.5)    return vec3(0.55, 0.85, 0.95);
    if (abs(materialId - MAT_ENTITY)  < 0.5)    return vec3(1.00, 0.55, 0.75);
    return vec3(0.70);
}

// Outdoor sky-fill estimate from scene luminance + depth (not exact lmcoord).
float debugSkyLightProxy(vec3 scene, float materialId, float linearZ) {
    if (isSkyMaterial(materialId)) return 1.0;
    float luma = dot(scene, vec3(0.299, 0.587, 0.114));
    float outdoor = smoothstep(0.06, 0.28, luma);
    float openAir = smoothstep(48.0, 6.0, linearZ);
    return clamp(outdoor * openAir, 0.0, 1.0);
}

// Block / torch warmth proxy — dark enclosed pixels with warm tint.
float debugBlockLightProxy(vec3 scene, float materialId, float linearZ) {
    if (isSkyMaterial(materialId)) return 0.0;
    float luma = dot(scene, vec3(0.299, 0.587, 0.114));
    float warm = smoothstep(0.35, 0.75, scene.r - scene.b * 0.35);
    float enclosed = smoothstep(32.0, 4.0, linearZ) * (1.0 - debugSkyLightProxy(scene, materialId, linearZ));
    return clamp(warm * enclosed * smoothstep(0.04, 0.22, luma), 0.0, 1.0);
}

vec3 applyDebugView(int mode, vec3 scene, vec4 gbuffer, float depth,
                    float linearZ, float haze, vec3 bloomExtract,
                    vec3 sunDir) {
    if (mode == 1) {
        return decodeNormal(gbuffer.rgb);
    }
    if (mode == 2) {
        return vec3(depth);
    }
    if (mode == 3) {
        float matId = readMaterialId(gbuffer);
        return debugMaterialColor(matId);
    }
    if (mode == 4) {
        vec3 n = decodeNormal(gbuffer.rgb);
        float ndotl = dot(n, normalize(sunDir)) * 0.5 + 0.5;
        return vec3(ndotl);
    }
    if (mode == 5) {
        float sky = debugSkyLightProxy(scene, readMaterialId(gbuffer), linearZ);
        return vec3(sky);
    }
    if (mode == 6) {
        float block = debugBlockLightProxy(scene, readMaterialId(gbuffer), linearZ);
        return vec3(block);
    }
    if (mode == 7) {
        return vec3(haze);
    }
    if (mode == 8) {
        return vec3(dot(bloomExtract, vec3(0.299, 0.587, 0.114)));
    }
    return scene;
}

#endif
