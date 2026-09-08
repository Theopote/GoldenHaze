/*
 * GoldenHaze — painterly lighting model (Phase 2.2)
 *
 * Replaces smooth Lambert falloff with 3–4 wide tonal bands:
 *   cool shadow → neutral mid → warm sun → (foliage) back-lit rim
 *
 * Phase 2.3 adds stylized sun shadow map modulation on outdoor surfaces.
 */

#include "/lib/gbuffer.glsl"
#include "/lib/shadow.glsl"

float painterlyStep(float edge0, float edge1, float x) {
    return smoothstep(edge0, edge1, x);
}

void lightmapVisibility(vec2 lmcoord, out float skyVis, out float blockVis) {
    skyVis   = smoothstep(0.02, 0.28, lmcoord.y);
    blockVis = smoothstep(0.02, 0.20, lmcoord.x);
}

void painterlyBandColors(float materialId, out vec3 shadowCol,
                         out vec3 midCol, out vec3 sunCol) {
    shadowCol = vec3(0.40, 0.42, 0.56);
    midCol    = vec3(0.76, 0.74, 0.68);
    sunCol    = vec3(1.06, 0.93, 0.66);

    if (abs(materialId - MAT_FOLIAGE) < 0.5) {
        shadowCol = vec3(0.26, 0.40, 0.36);
        midCol    = vec3(0.62, 0.78, 0.42);
        sunCol    = vec3(1.04, 0.96, 0.50);
    } else if (abs(materialId - MAT_WATER) < 0.5) {
        shadowCol = vec3(0.22, 0.42, 0.52);
        midCol    = vec3(0.48, 0.72, 0.78);
        sunCol    = vec3(0.82, 0.96, 1.08);
    }
}

vec3 painterlyDirectionalLight(vec3 normal, vec3 sunDir, float materialId,
                               float skyVis, float sunShadow) {
    float NdotL = dot(normalize(normal), normalize(sunDir));

    vec3 shadowCol, midCol, sunCol;
    painterlyBandColors(materialId, shadowCol, midCol, sunCol);

    float litBand = painterlyStep(-0.18, 0.22, NdotL);
    float sunBand = painterlyStep(0.18, 0.58, NdotL);

    vec3 lightColor = mix(shadowCol, midCol, litBand);
    lightColor = mix(lightColor, sunCol, sunBand);

    lightColor *= skyVis;

    // Shadow map: broad sun occlusion with a cool tint (not ink-black).
    float shadowMul = mix(0.32, 1.0, sunShadow);
    lightColor *= shadowMul;
    lightColor *= mix(stylizedShadowTint(sunShadow), vec3(1.0), sunShadow);

    if (abs(materialId - MAT_FOLIAGE) < 0.5) {
        float rim = painterlyStep(0.10, 0.50, -NdotL) * skyVis;
        lightColor += vec3(0.42, 0.52, 0.20) * rim * 0.50;
    }

    return lightColor;
}

vec3 painterlyAmbientFill(float skyVis, float blockVis, vec3 vanillaLight) {
    vec3 caveFill  = vec3(0.09, 0.10, 0.15) * (1.0 - skyVis);
    vec3 torchFill = vec3(1.00, 0.80, 0.52) * blockVis;
    vec3 vanillaHint = vanillaLight * 0.35 * (1.0 - skyVis);
    return caveFill + torchFill + vanillaHint;
}

vec3 shadePainterly(vec3 albedo, vec3 normal, vec3 sunDir, vec2 lmcoord,
                    vec3 vanillaLight, float materialId, float rainStrength,
                    float strength, vec3 feetPlayerPos,
                    float shadowStrength, float shadowSoftness) {
    float skyVis, blockVis;
    lightmapVisibility(lmcoord, skyVis, blockVis);

    float sunShadow = stylizedSunShadow(feetPlayerPos, normal, sunDir, skyVis,
                                        shadowStrength, shadowSoftness);

    vec3 directional = painterlyDirectionalLight(normal, sunDir, materialId,
                                                 skyVis, sunShadow);
    vec3 ambient     = painterlyAmbientFill(skyVis, blockVis, vanillaLight);

    vec3 lightColor = directional + ambient;

    float outdoor = skyVis * (1.0 - blockVis * 0.35);
    lightColor = mix(lightColor,
                     mix(lightColor, vec3(dot(lightColor, vec3(0.333))), 0.45),
                     rainStrength * outdoor);

    vec3 painterly = albedo * lightColor;
    vec3 vanilla   = albedo * vanillaLight;

    return mix(vanilla, painterly, strength);
}
