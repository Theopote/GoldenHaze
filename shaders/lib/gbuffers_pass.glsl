/*
 * GoldenHaze — shared gbuffers pass helpers (Phase 2.8)
 *
 * Thin wrappers so entities / hand / particles / weather share the same
 * painterly + palette + GBuffer output as terrain.
 */

#include "/lib/painterly.glsl"

vec3 shadeUnlitTextured(vec3 albedo, vec3 sunDir, float rainStrength) {
    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float day     = smoothstep(-0.10, 0.25, sunUp);
    float outdoor = mix(0.38, 1.00, day);
    vec3 ambient  = mix(vec3(0.32, 0.34, 0.44), vec3(0.94, 0.90, 0.84), day);
    vec3 lit = albedo * ambient * outdoor;
    lit = mix(lit, vec3(dot(lit, vec3(0.333))) * 0.65, rainStrength * 0.45);
    return lit;
}

void writeLitGbuffer(vec3 albedo, float alpha, vec3 normal, vec3 worldNormal,
                     vec2 lmcoord, vec3 feetPlayerPos, float materialId,
                     vec3 sunDir, float rainStrength, float paletteStrength,
                     float painterlyStrength, float shadowStrength,
                     float shadowSoftness) {
    vec3 vanillaLight = texture2D(lightmap, lmcoord).rgb;
    vec3 baseAlbedo   = applyMaterialPalette(albedo, materialId, paletteStrength);
    vec3 litColor     = shadePainterly(baseAlbedo, normal, worldNormal, sunDir,
                                       lmcoord, vanillaLight, materialId,
                                       rainStrength, painterlyStrength,
                                       feetPlayerPos, shadowStrength,
                                       shadowSoftness);

    gl_FragData[0] = vec4(litColor, alpha);
    gl_FragData[1] = packGBuffer(normal, materialId);
}

void writeUnlitGbuffer(vec3 albedo, float alpha, vec3 normal, float materialId,
                       vec3 sunDir, float rainStrength) {
    vec3 litColor = shadeUnlitTextured(albedo, sunDir, rainStrength);
    gl_FragData[0] = vec4(litColor, alpha);
    gl_FragData[1] = packGBuffer(normal, materialId);
}

// Rain/snow quads: lightmap as visibility info, not final color multiplier.
void writeWeatherGbuffer(vec3 albedo, float alpha, vec2 lmcoord, vec3 normal,
                         vec3 worldNormal, vec3 sunDir, float rainStrength) {
    float skyVis, blockVis;
    lightmapVisibility(lmcoord, skyVis, blockVis);

    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float day   = smoothstep(-0.10, 0.25, sunUp);

    vec3 rainTint = mix(vec3(0.58, 0.70, 0.86), vec3(0.80, 0.86, 0.98), day);
    vec3 snowTint = mix(vec3(0.72, 0.78, 0.90), vec3(0.94, 0.96, 1.02), day);
    vec3 tint = mix(rainTint, snowTint, smoothstep(0.35, 0.75, albedo.r + albedo.b));

    vec3 base = mix(albedo, tint, 0.62);
    vec3 skyFill = painterlySkyFill(worldNormal, skyVis) * SKY_STRENGTH;
    vec3 ambient = painterlyAmbientFill(skyVis, blockVis, vec3(0.5)) + skyFill;
    vec3 lit = base * ambient;
    lit = mix(lit, vec3(dot(lit, vec3(0.333))) * 0.55, rainStrength * 0.65);

    gl_FragData[0] = vec4(lit, alpha);
    gl_FragData[1] = packGBuffer(normal, MAT_DEFAULT);
}

void writeEntityGbuffer(vec3 albedo, float alpha, vec3 normal, vec3 worldNormal,
                        vec2 lmcoord, vec3 feetPlayerPos, vec3 sunDir,
                        float rainStrength, float paletteStrength,
                        float painterlyStrength, float shadowStrength,
                        float shadowSoftness) {
    writeLitGbuffer(albedo, alpha, normal, worldNormal, lmcoord, feetPlayerPos,
                    MAT_ENTITY, sunDir, rainStrength, paletteStrength,
                    painterlyStrength, shadowStrength, shadowSoftness);
}

void writeSpiderEyesGbuffer(vec3 albedo, float alpha, vec3 normal,
                            vec3 sunDir) {
    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float day   = smoothstep(-0.10, 0.25, sunUp);
    vec3 glow   = albedo * mix(vec3(0.70, 0.22, 0.92), vec3(1.10, 0.42, 1.05), day);
    glow *= 1.35;

    gl_FragData[0] = vec4(glow, alpha);
    gl_FragData[1] = packGBuffer(normal, MAT_ENTITY);
}

void writeArmorGlintGbuffer(vec3 albedo, float alpha, vec3 normal,
                            vec3 worldNormal, vec2 lmcoord, vec3 feetPlayerPos,
                            vec3 sunDir, float rainStrength,
                            float painterlyStrength, float shadowStrength,
                            float shadowSoftness) {
    vec3 vanillaLight = texture2D(lightmap, lmcoord).rgb;
    vec3 baseAlbedo   = applyMaterialPalette(albedo, MAT_ENTITY, 0.35);
    vec3 litColor     = shadePainterly(baseAlbedo, normal, worldNormal, sunDir,
                                       lmcoord, vanillaLight, MAT_ENTITY,
                                       rainStrength, painterlyStrength,
                                       feetPlayerPos, shadowStrength,
                                       shadowSoftness);
    vec3 glint = albedo * vec3(1.15, 1.05, 0.72) * 1.6;
    litColor = mix(litColor, glint, 0.55);

    gl_FragData[0] = vec4(litColor, alpha);
    gl_FragData[1] = packGBuffer(normal, MAT_ENTITY);
}

void writeLightningGbuffer(vec3 albedo, float alpha, vec3 normal, vec3 sunDir) {
    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float day   = smoothstep(-0.10, 0.25, sunUp);
    vec3 bolt   = albedo * mix(vec3(0.85, 0.92, 1.15), vec3(1.20, 1.10, 0.85), day);
    bolt *= 1.8;

    gl_FragData[0] = vec4(bolt, alpha);
    gl_FragData[1] = packGBuffer(normal, MAT_ENTITY);
}
