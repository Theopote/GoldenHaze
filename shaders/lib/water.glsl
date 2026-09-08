/*
 * GoldenHaze — Water 2.0 (Phase 2.5)
 *
 * Replaces vanilla water texture tinting with a painterly palette:
 *   near  — clear teal, slight texture read-through
 *   mid   — cyan-green blocks
 *   far   — sky-reflected blue
 *   sunset— warm orange shift
 *
 * Highlights are horizontal intermittent bands (animation-style),
 * not random noise sparkles.
 */

float waterHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float waterVnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(waterHash(i),               waterHash(i + vec2(1.0, 0.0)), u.x),
               mix(waterHash(i + vec2(0.0, 1.0)), waterHash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

// Day / sunset palettes for horizon-reflected far water.
void waterSkyPalette(vec3 sunDir, float rainStrength,
                     out vec3 nearCol, out vec3 midCol,
                     out vec3 farCol, out vec3 sunsetCol) {
    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float day     = smoothstep(-0.10, 0.25, sunUp);
    float sunset  = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);

    nearCol   = vec3(0.22, 0.52, 0.58);
    midCol    = vec3(0.18, 0.55, 0.48);
    farCol    = mix(vec3(0.12, 0.18, 0.32), vec3(0.42, 0.66, 0.92), day);
    sunsetCol = vec3(0.82, 0.48, 0.32);

    vec3 gray = vec3(dot(farCol, vec3(0.333))) * 0.7;
    farCol = mix(farCol, gray, rainStrength * 0.55);
    midCol = mix(midCol, gray, rainStrength * 0.40);
}

// Distance + grazing-angle palette blend (replaces vanilla water tint).
vec3 waterPaletteAlbedo(vec3 albedo, vec3 worldPos, vec3 feetPlayerPos,
                        vec3 normal, vec3 viewDir, vec3 sunDir,
                        float skyVis, float rainStrength,
                        float distNear, float distFar, float strength) {
    vec3 nearCol, midCol, farCol, sunsetCol;
    waterSkyPalette(sunDir, rainStrength, nearCol, midCol, farCol, sunsetCol);

    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float sunset = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);

    float horizDist = length(feetPlayerPos.xz);
    float farT  = smoothstep(distNear * 2.5, distFar, horizDist);
    float midT  = smoothstep(distNear, distNear * 4.0, horizDist) * (1.0 - farT);

    vec3 palette = nearCol;
    palette = mix(palette, midCol, midT);
    palette = mix(palette, farCol, farT);
    palette = mix(palette, sunsetCol, sunset * farT * 0.85);

    // Grazing view angles pick up more sky/reflection color.
    float fresnel = pow(1.0 - max(dot(normalize(normal), normalize(viewDir)), 0.0), 2.8);
    palette = mix(palette, farCol * 1.08, fresnel * 0.55 * skyVis);

    // Near water keeps a hint of block texture; far water fully palette-driven.
    float texRetain = mix(0.45, 0.05, farT);
    vec3 stylized = mix(palette, albedo * palette * 2.2, texRetain);

    // Caves / enclosed water stay dark; outdoor palette only with sky light.
    vec3 caveWater = albedo * vec3(0.12, 0.16, 0.22);
    stylized = mix(caveWater, stylized, skyVis);

    return mix(albedo, stylized, strength);
}

// Thin horizontal highlight bands with noise breakup — painted sun glints.
vec3 waterStylizedHighlights(vec3 lit, vec3 worldPos, vec3 normal, vec3 viewDir,
                             vec3 sunDir, float skyVis, float frameTime,
                             float strength) {
    float upFacing = smoothstep(0.45, 0.88, normal.y);
    if (upFacing < 0.01 || skyVis < 0.05 || strength < 0.001) {
        return lit;
    }

    vec2 wp = worldPos.xz;

    // Dominantly horizontal bands (world-X ripples, slight diagonal drift).
    float waveA = sin(wp.x * 0.42 + frameTime * 0.22) * 0.5 + 0.5;
    float waveB = sin(wp.x * 0.19 - wp.z * 0.08 + frameTime * 0.14) * 0.5 + 0.5;
    float band  = smoothstep(0.68, 0.90, waveA * waveB);

    // Break bands into short dashes instead of continuous lines.
    float dash = waterVnoise(vec2(wp.x * 0.11, wp.z * 0.04) + frameTime * 0.06);
    band *= smoothstep(0.40, 0.72, dash);

    // Narrow bright cores within the band.
    float core = smoothstep(0.82, 0.96, sin(wp.x * 1.1 + frameTime * 0.35) * 0.5 + 0.5);
    band = max(band * 0.75, core * 0.45);

    float sunFace = max(dot(normalize(normal), normalize(sunDir)), 0.0);
    float viewGrazing = pow(1.0 - max(dot(normalize(normal), normalize(viewDir)), 0.0), 1.5);

    float highlight = band * sunFace * viewGrazing * skyVis * upFacing;
    return lit + vec3(1.08, 1.00, 0.82) * highlight * strength * 0.85;
}

/*
 * Full water pass: palette albedo replacement + painterly lit input + highlights.
 */
vec3 applyWaterShading(vec3 albedo, vec3 painterlyLit, vec3 worldPos,
                       vec3 feetPlayerPos, vec3 normal, vec3 viewDir,
                       vec3 sunDir, vec2 lmcoord, float rainStrength,
                       float frameTime, float waterStrength,
                       float highlightStrength, float distNear, float distFar) {
    float skyVis, blockVis;
    skyVis   = smoothstep(0.02, 0.28, lmcoord.y);
    blockVis = smoothstep(0.02, 0.20, lmcoord.x);

    vec3 paletteAlbedo = waterPaletteAlbedo(albedo, worldPos, feetPlayerPos,
                                            normal, viewDir, sunDir, skyVis,
                                            rainStrength, distNear, distFar,
                                            waterStrength);

    vec3 tintRatio = paletteAlbedo / max(albedo, vec3(0.001));
    vec3 lit = painterlyLit * tintRatio;

    lit = waterStylizedHighlights(lit, worldPos, normal, viewDir, sunDir,
                                  skyVis, frameTime, highlightStrength);

    return mix(painterlyLit, lit, waterStrength);
}
