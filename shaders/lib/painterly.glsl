/*
 * GoldenHaze — painterly lighting model (Phase 2.2 + three-light)
 *
 * Sun  — warm directional bands (wide smoothsteps, not hard toon)
 * Sky  — cool hemisphere fill for occluded sides
 * Bounce — subtle ground-tinted underside (artistic cheat, not GI)
 *
 * Phase 2.3 adds stylized sun occlusion map on outdoor surfaces.
 *
 * Avoid local/global identifiers named "tint" — Iris Sodium injects
 * a varying of that name into terrain fragment shaders.
 */

#ifndef GOLDENHAZE_PAINTERLY
#define GOLDENHAZE_PAINTERLY

#include "/lib/shadow.glsl"
#include "/lib/palette.glsl"

#define SUN_STRENGTH   1.0 // [0.00 0.50 0.75 1.00 1.25 1.50]
#define SKY_STRENGTH   0.60 // [0.00 0.40 0.55 0.60 0.70 0.85 1.00]
#define BOUNCE_STRENGTH 0.20 // [0.00 0.10 0.15 0.20 0.25 0.35 0.50]

float painterlyStep(float edge0, float edge1, float x) {
    return smoothstep(edge0, edge1, x);
}

void lightmapVisibility(vec2 lmcoord, out float skyVis, out float blockVis) {
    skyVis   = smoothstep(0.02, 0.28, lmcoord.y);
    blockVis = smoothstep(0.02, 0.20, lmcoord.x);
}

void painterlyBandColors(float materialId, out vec3 toneLo,
                         out vec3 toneMd, out vec3 toneHi) {
    materialPaletteBands(materialId, toneLo, toneMd, toneHi);
}

// Time-of-day sun color: pale morning, cream noon, orange dusk.
vec3 painterlySunPhase(vec3 lightDir) {
    float sunUp = clamp(normalize(lightDir).y, -1.0, 1.0);
    float morning = smoothstep(-0.05, 0.30, sunUp)
                  * (1.0 - smoothstep(0.30, 0.62, sunUp));
    float noonAmt = smoothstep(0.22, 0.72, sunUp);
    float duskAmt = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);

    vec3 morningRgb = vec3(1.02, 0.98, 0.72);
    vec3 noonRgb    = vec3(1.06, 1.02, 0.88);
    vec3 duskRgb    = vec3(1.12, 0.72, 0.42);

    vec3 phaseRgb = mix(vec3(1.0), noonRgb, noonAmt);
    phaseRgb = mix(phaseRgb, morningRgb, morning * 0.85);
    phaseRgb = mix(phaseRgb, duskRgb, duskAmt * 0.90);
    return phaseRgb;
}

vec3 painterlySkyFill(vec3 worldNormal, float skyVis) {
    float up = worldNormal.y * 0.5 + 0.5;
    vec3 coolSky  = vec3(0.46, 0.56, 0.72);
    vec3 blueGray = vec3(0.34, 0.40, 0.52);
    return mix(blueGray, coolSky, up) * skyVis;
}

vec3 painterlyBounceFill(vec3 worldNormal, float materialId, vec3 lightDir,
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

    float sunUp = clamp(normalize(lightDir).y, -1.0, 1.0);
    float duskAmt = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);
    bounce = mix(bounce, vec3(0.62, 0.38, 0.22), duskAmt * 0.65);

    return bounce * groundFacing * skyVis;
}

vec3 painterlyDirectionalLight(vec3 viewNormal, vec3 lightDir, float materialId,
                               float skyVis, float sunLit) {
    float NdotL = dot(normalize(viewNormal), normalize(lightDir));

    vec3 toneLo, toneMd, toneHi;
    painterlyBandColors(materialId, toneLo, toneMd, toneHi);

    float litBand = painterlyStep(-0.18, 0.22, NdotL);
    float sunBand = painterlyStep(0.18, 0.58, NdotL);

    vec3 lightColor = mix(toneLo, toneMd, litBand);
    lightColor = mix(lightColor, toneHi, sunBand);

    lightColor *= skyVis;
    lightColor *= painterlySunPhase(lightDir);

    float shadeMul = mix(0.32, 1.0, sunLit);
    lightColor *= shadeMul;
    lightColor *= mix(ghShadeMul(sunLit), vec3(1.0), sunLit);

    return lightColor;
}

vec3 painterlyAmbientFill(float skyVis, float blockVis, vec3 vanillaLight) {
    vec3 caveFill  = vec3(0.09, 0.10, 0.15) * (1.0 - skyVis);
    vec3 torchFill = vec3(1.00, 0.80, 0.52) * blockVis;
    vec3 vanillaHint = vanillaLight * 0.35 * (1.0 - skyVis);
    return caveFill + torchFill + vanillaHint;
}

vec3 shadePainterly(vec3 albedo, vec3 viewNormal, vec3 worldNormal, vec3 lightDir,
                    vec2 lmcoord, vec3 vanillaLight, float materialId,
                    float rainStrength, float strength, vec3 feetPlayerPos,
                    float shadowStrength, float shadowSoftness) {
    float skyVis, blockVis;
    lightmapVisibility(lmcoord, skyVis, blockVis);

    float sunLit = ghMapSunLit(feetPlayerPos, viewNormal, lightDir, skyVis,
                               shadowStrength, shadowSoftness);

    vec3 sunLight  = painterlyDirectionalLight(viewNormal, lightDir, materialId,
                                               skyVis, sunLit) * SUN_STRENGTH;
    vec3 skyLight  = painterlySkyFill(worldNormal, skyVis) * SKY_STRENGTH;
    vec3 bounce    = painterlyBounceFill(worldNormal, materialId, lightDir, skyVis)
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
