/*
 * GoldenHaze — Foliage 2.0 (Phase 2.4)
 *
 * Turns leaf blocks from "textured quads + sparkle" into canopy volumes:
 *   - world-space bright/dark masses
 *   - vertical palette (warm top / cool underside)
 *   - sun-facing vs back-lit color shift
 *   - interior canopy shadow from sky-light occlusion
 *   - back-lit rim translucency
 *   - integrated sun flecks
 */

#ifndef GOLDENHAZE_FOLIAGE
#define GOLDENHAZE_FOLIAGE

float foliageHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float foliageVnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(foliageHash(i),               foliageHash(i + vec2(1.0, 0.0)), u.x),
               mix(foliageHash(i + vec2(0.0, 1.0)), foliageHash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

float foliageVolumeNoise(vec3 worldPos) {
    vec2 macro = worldPos.xz * 0.045 + worldPos.y * 0.018;
    float n1 = foliageVnoise(macro);
    float n2 = foliageVnoise(macro * 1.9 + vec2(4.1, 2.7));
    return n1 * 0.65 + n2 * 0.35;
}

// Warm top / natural mid / cool underside — worldNormal + weak world height.
vec3 foliageVerticalPalette(vec3 albedo, vec3 worldPos, vec3 worldNormal,
                            float skyVis) {
    float topFace    = smoothstep(0.20, 0.82,  worldNormal.y);
    float bottomFace = smoothstep(0.20, 0.82, -worldNormal.y);

    vec3 topTint    = vec3(1.14, 1.10, 0.78);
    vec3 bottomTint = vec3(0.70, 0.90, 0.86);
    vec3 midTint    = vec3(0.96, 1.02, 0.94);

    float heightBand = sin(worldPos.y * 0.11) * 0.5 + 0.5;

    vec3 leafMul = midTint;
    leafMul = mix(leafMul, topTint,    topFace * 0.85 + heightBand * 0.15);
    leafMul = mix(leafMul, bottomTint, bottomFace * 0.80);

    return albedo * mix(vec3(1.0), leafMul, skyVis);
}

// Sun-facing warm yellow-green vs back-facing blue-green.
vec3 foliageFacingTint(vec3 albedo, vec3 viewNormal, vec3 sunDir, float skyVis) {
    float NdotL   = dot(normalize(viewNormal), normalize(sunDir));
    float sunFace = smoothstep(-0.12, 0.48, NdotL) * skyVis;
    float backFace = smoothstep(-0.12, 0.48, -NdotL) * skyVis;

    vec3 sunTint  = vec3(1.10, 1.04, 0.82);
    vec3 backTint = vec3(0.78, 0.94, 0.88);

    albedo *= mix(vec3(1.0), sunTint,  sunFace * 0.55);
    albedo *= mix(vec3(1.0), backTint, backFace * 0.40);
    return albedo;
}

// Large canopy masses + sky-light occlusion for interior darkness.
vec3 foliageCanopyShade(vec3 lit, vec3 worldPos, vec2 lmcoord, float skyVis) {
    float volume = foliageVolumeNoise(worldPos);
    float massLit = smoothstep(0.32, 0.68, volume);
    lit *= mix(0.62, 1.05, massLit);

    // Low sky light = deep under canopy; noise thickens interior clumps.
    float skyOpen = smoothstep(0.08, 0.55, lmcoord.y);
    float density = smoothstep(0.28, 0.72, foliageVnoise(worldPos.xz * 0.08));
    float interior = mix(0.42, 1.0, skyOpen);
    interior = mix(interior, interior * 0.72, density * (1.0 - skyOpen));

    lit *= mix(1.0, interior, skyVis);
    return lit;
}

vec3 foliageRimTranslucency(vec3 lit, vec3 viewNormal, vec3 sunDir, float skyVis) {
    float NdotL = dot(normalize(viewNormal), normalize(sunDir));
    float rim   = smoothstep(0.12, 0.52, -NdotL) * skyVis;
    return lit + vec3(0.38, 0.48, 0.16) * rim * 0.55;
}

vec3 foliageSunFlecks(vec3 lit, vec3 worldPos, float skyVis,
                      float frameTime, float shimmerStrength) {
    // Wind gust gates WHEN flecks appear; noise gates WHERE (not crawling UVs).
    float gust = sin(frameTime * 0.70 + worldPos.x * 0.05 + worldPos.z * 0.04) * 0.5 + 0.5;
    float gustGate = smoothstep(0.40, 0.76, gust);

    vec2 sp  = worldPos.xz * 2.5 + vec2(worldPos.y * 1.7);
    float n1 = foliageVnoise(sp * 3.0);
    float n2 = foliageVnoise(sp * 5.0 + vec2(4.2, 1.8));
    float fleck = smoothstep(0.78, 0.95, n1 * n2 * 2.0);

    float volume = foliageVolumeNoise(worldPos);
    float onBrightMass = smoothstep(0.45, 0.75, volume);

    float sparkle = fleck * skyVis * shimmerStrength * onBrightMass * gustGate;
    return lit + vec3(1.00, 0.85, 0.55) * sparkle * 0.55;
}

/*
 * Post-painterly foliage pass. `painterlyLit` = shadePainterly(...) output.
 * `baseAlbedo`    = texture albedo before lighting (for tint ratio).
 */
vec3 applyFoliageShading(vec3 baseAlbedo, vec3 painterlyLit, vec3 worldPos,
                         vec3 viewNormal, vec3 worldNormal, vec3 sunDir,
                         vec2 lmcoord, float skyVis, float frameTime,
                         float foliageStrength, float shimmerStrength) {
    if (foliageStrength < 0.001) {
        return painterlyLit;
    }

    vec3 tinted = foliageVerticalPalette(baseAlbedo, worldPos, worldNormal, skyVis);
    tinted = foliageFacingTint(tinted, viewNormal, sunDir, skyVis);

    vec3 tintRatio = tinted / max(baseAlbedo, vec3(0.001));
    vec3 lit = painterlyLit * tintRatio;

    lit = foliageCanopyShade(lit, worldPos, lmcoord, skyVis);
    lit = foliageRimTranslucency(lit, viewNormal, sunDir, skyVis);
    lit = foliageSunFlecks(lit, worldPos, skyVis, frameTime, shimmerStrength);

    return mix(painterlyLit, lit, foliageStrength);
}

#endif
