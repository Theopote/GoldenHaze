/*
 * GoldenHaze — painterly lighting model (Phase 2.2 + three-light)
 *
 * Sun  — warm directional bands (wide smoothsteps, not hard toon)
 * Sky  — cool hemisphere fill for shadow sides
 * Bounce — subtle ground-tinted underside (artistic cheat, not GI)
 *
 * Phase 2.3 adds stylized sun shadow map on outdoor surfaces.
 */

#ifndef GOLDENHAZE_PAINTERLY
#define GOLDENHAZE_PAINTERLY

#include "/lib/shadow.glsl"
#include "/lib/palette.glsl"

#define SUN_STRENGTH   1.0 // [0.00 0.50 0.75 1.00 1.25 1.50]
#define SKY_STRENGTH   0.85 // [0.00 0.40 0.65 0.85 1.00 1.25]
#define BOUNCE_STRENGTH 0.35 // [0.00 0.15 0.25 0.35 0.50 0.75]

float painterlyStep(float edge0, float edge1, float x) {
    return smoothstep(edge0, edge1, x);
}

void lightmapVisibility(vec2 lmcoord, out float skyVis, out float blockVis) {
    skyVis   = smoothstep(0.02, 0.28, lmcoord.y);
    blockVis = smoothstep(0.02, 0.20, lmcoord.x);
}

void painterlyBandColors(float materialId, out vec3 shadowCol,
                         out vec3 midCol, out vec3 sunCol) {
    materialPaletteBands(materialId, shadowCol, midCol, sunCol);
}

// Time-of-day sun tint: pale morning → cream noon → golden afternoon → orange sunset.
vec3 painterlySunTint(vec3 sunDir) {
    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float morning = smoothstep(-0.05, 0.30, sunUp)
                  * (1.0 - smoothstep(0.30, 0.62, sunUp));
    float noon    = smoothstep(0.22, 0.72, sunUp);
    float sunset  = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);

    vec3 morningCol = vec3(1.02, 0.98, 0.72);
    vec3 noonCol    = vec3(1.06, 1.02, 0.88);
    vec3 sunsetCol  = vec3(1.12, 0.72, 0.42);

    vec3 tint = mix(vec3(1.0), noonCol, noon);
    tint = mix(tint, morningCol, morning * 0.85);
    tint = mix(tint, sunsetCol, sunset * 0.90);
    return tint;
}

// Cool sky hemisphere — fills shadow sides with blue-gray instead of black.
vec3 painterlySkyFill(vec3 worldNormal, float skyVis) {
    float up = worldNormal.y * 0.5 + 0.5;
    vec3 coolSky  = vec3(0.46, 0.56, 0.72);
    vec3 blueGray = vec3(0.34, 0.40, 0.52);
    return mix(blueGray, coolSky, up) * skyVis;
}

// Ground-facing bounce tint — material-aware artistic fill, not real GI.
vec3 painterlyBounceFill(vec3 worldNormal, float materialId, vec3 sunDir,
                         float skyVis) {
    float groundFacing = clamp(-worldNormal.y, 0.0, 1.0);
    if (groundFacing < 0.001 || skyVis < 0.01) {
        return vec3(0.0);
    }

    vec3 bounce = vec3(0.24, 0.44, 0.20);
    if (abs(materialId - MAT_SOIL) < 0.5)        bounce = vec3(0.52, 0.44, 0.28);
    else if (abs(materialId - MAT_STONE) < 0.5)  bounce = vec3(0.32, 0.36, 0.42);
    else if (abs(materialId - MAT_SNOW) < 0.5)   bounce = vec3(0.55, 0.62, 0.78);
    else if (abs(materialId - MAT_WOOD) < 0.5)   bounce = vec3(0.48, 0.36, 0.24);
    else if (abs(materialId - MAT_TERRACOTTA) < 0.5) bounce = vec3(0.58, 0.36, 0.24);

    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float sunset = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);
    bounce = mix(bounce, vec3(0.62, 0.38, 0.22), sunset * 0.65);

    return bounce * groundFacing * skyVis;
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
    lightColor *= painterlySunTint(sunDir);

    float shadowMul = mix(0.32, 1.0, sunShadow);
    lightColor *= shadowMul;
    lightColor *= mix(stylizedShadowTint(sunShadow), vec3(1.0), sunShadow);

    return lightColor;
}

vec3 painterlyAmbientFill(float skyVis, float blockVis, vec3 vanillaLight) {
    vec3 caveFill  = vec3(0.09, 0.10, 0.15) * (1.0 - skyVis);
    vec3 torchFill = vec3(1.00, 0.80, 0.52) * blockVis;
    vec3 vanillaHint = vanillaLight * 0.35 * (1.0 - skyVis);
    return caveFill + torchFill + vanillaHint;
}

vec3 shadePainterly(vec3 albedo, vec3 normal, vec3 worldNormal, vec3 sunDir,
                    vec2 lmcoord, vec3 vanillaLight, float materialId,
                    float rainStrength, float strength, vec3 feetPlayerPos,
                    float shadowStrength, float shadowSoftness) {
    float skyVis, blockVis;
    lightmapVisibility(lmcoord, skyVis, blockVis);

    float sunShadow = stylizedSunShadow(feetPlayerPos, normal, sunDir, skyVis,
                                        shadowStrength, shadowSoftness);

    vec3 sunLight  = painterlyDirectionalLight(normal, sunDir, materialId,
                                               skyVis, sunShadow) * SUN_STRENGTH;
    vec3 skyLight  = painterlySkyFill(worldNormal, skyVis) * SKY_STRENGTH;
    vec3 bounce    = painterlyBounceFill(worldNormal, materialId, sunDir, skyVis)
                   * BOUNCE_STRENGTH;
    vec3 ambient   = painterlyAmbientFill(skyVis, blockVis, vanillaLight)
                   + skyLight + bounce;

    vec3 lightColor = sunLight + ambient;

    float outdoor = skyVis * (1.0 - blockVis * 0.35);
    lightColor = mix(lightColor,
                     mix(lightColor, vec3(dot(lightColor, vec3(0.333))), 0.45),
                     rainStrength * outdoor);

    vec3 painterly = albedo * lightColor;
    vec3 vanilla   = albedo * vanillaLight;

    return mix(vanilla, painterly, strength);
}

#endif
