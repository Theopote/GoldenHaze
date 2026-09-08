/*
 * GoldenHaze — Water 2.0 four-layer model
 *
 * 1. Base water color   — near / mid / far *distance* palette
 *                        (horizDist = length(feetPlayerPos.xz);
 *                         NOT optical water depth. True depth via
 *                         depthtex comparison is deferred — distance
 *                         bands are enough for Phase 2.)
 * 2. Sky reflection     — view-angle Fresnel mix
 * 3. Sun ribbon         — horizontal broken highlight bands
 * 4. Micro sparkles     — subtle point glints on ribbons
 *
 * Space contract:
 *   viewNormal  — view-space (NdotL with sunPosition)
 *   worldNormal — world-space (up-facing, Fresnel with toCamera)
 *   viewDir     — world-space direction from surface toward camera
 *                 (cameraPosition - worldPos). Name kept for varying
 *                 compatibility; treat as to-camera, not camera-to-surface.
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

void waterSkyPalette(vec3 sunDir, float rainStrength,
                     out vec3 waterNear, out vec3 waterMid,
                     out vec3 waterFar, out vec3 waterSunset) {
    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float day     = smoothstep(-0.10, 0.25, sunUp);
    float sunset  = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);

    waterNear   = vec3(0.22, 0.52, 0.58);
    waterMid    = vec3(0.18, 0.55, 0.48);
    waterFar    = mix(vec3(0.12, 0.18, 0.32), vec3(0.42, 0.66, 0.92), day);
    waterSunset = vec3(0.82, 0.48, 0.32);

    vec3 gray = vec3(dot(waterFar, vec3(0.333))) * 0.7;
    waterFar = mix(waterFar, gray, rainStrength * 0.55);
    waterMid = mix(waterMid, gray, rainStrength * 0.40);
}

// Layer 1 — base palette by *camera distance* (near / mid / far), not water depth.
vec3 waterLayerBase(vec3 albedo, vec3 worldPos, vec3 feetPlayerPos,
                    vec3 sunDir, float skyVis, float rainStrength,
                    float distNear, float distFar) {
    vec3 waterNear, waterMid, waterFar, waterSunset;
    waterSkyPalette(sunDir, rainStrength, waterNear, waterMid, waterFar, waterSunset);

    float sunUp = clamp(normalize(sunDir).y, -1.0, 1.0);
    float sunset = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);

    float horizDist = length(feetPlayerPos.xz);
    float farT  = smoothstep(distNear * 2.5, distFar, horizDist);
    float midT  = smoothstep(distNear, distNear * 4.0, horizDist) * (1.0 - farT);

    vec3 palette = waterNear;
    palette = mix(palette, waterMid, midT);
    palette = mix(palette, waterFar, farT);
    palette = mix(palette, waterSunset, sunset * farT * 0.85);

    float texRetain = mix(0.45, 0.05, farT);
    vec3 stylized = mix(palette, albedo * palette * 2.2, texRetain);

    vec3 caveWater = albedo * vec3(0.12, 0.16, 0.22);
    return mix(caveWater, stylized, skyVis);
}

// Layer 2 — sky reflection via grazing view angle (stylized Fresnel).
// worldNormal + viewDir(to-camera) are both world-space.
vec3 waterLayerSkyReflection(vec3 baseRgb, vec3 worldNormal, vec3 viewDir,
                             vec3 waterFar, float skyVis) {
    float NdotV = max(dot(normalize(worldNormal), normalize(viewDir)), 0.0);
    float fresnel = pow(1.0 - NdotV, 2.8);
    return mix(baseRgb, waterFar * 1.08, fresnel * 0.55 * skyVis);
}

// Layer 3 — horizontal sun ribbon bands (world up for horizontal water).
float waterSunRibbonMask(vec3 worldPos, vec3 viewNormal, vec3 worldNormal,
                         vec3 viewDir, vec3 sunDir, float skyVis,
                         float frameTime) {
    float upFacing = smoothstep(0.45, 0.88, worldNormal.y);
    if (upFacing < 0.01 || skyVis < 0.05) return 0.0;

    vec2 wp = worldPos.xz;
    float waveA = sin(wp.x * 0.42 + frameTime * 0.22) * 0.5 + 0.5;
    float waveB = sin(wp.x * 0.19 - wp.z * 0.08 + frameTime * 0.14) * 0.5 + 0.5;
    float band  = smoothstep(0.68, 0.90, waveA * waveB);

    float dash = waterVnoise(vec2(wp.x * 0.11, wp.z * 0.04) + frameTime * 0.06);
    band *= smoothstep(0.40, 0.72, dash);

    // sunDir / viewNormal are view-space; grazing uses world-space pair.
    float sunFace = max(dot(normalize(viewNormal), normalize(sunDir)), 0.0);
    float NdotV = max(dot(normalize(worldNormal), normalize(viewDir)), 0.0);
    float viewGrazing = pow(1.0 - NdotV, 1.5);

    return band * sunFace * viewGrazing * skyVis * upFacing;
}

// Layer 4 — micro sparkles riding on ribbon cores.
float waterMicroSparkle(vec3 worldPos, float frameTime, float ribbonMask) {
    float core = smoothstep(0.82, 0.96,
                            sin(worldPos.x * 1.1 + frameTime * 0.35) * 0.5 + 0.5);
    return core * ribbonMask * 0.45;
}

vec3 waterPaletteAlbedo(vec3 albedo, vec3 worldPos, vec3 feetPlayerPos,
                        vec3 worldNormal, vec3 viewDir, vec3 sunDir,
                        float skyVis, float rainStrength,
                        float distNear, float distFar, float strength) {
    vec3 base = waterLayerBase(albedo, worldPos, feetPlayerPos, sunDir, skyVis,
                               rainStrength, distNear, distFar);

    vec3 waterNear, waterMid, waterFar, waterSunset;
    waterSkyPalette(sunDir, rainStrength, waterNear, waterMid, waterFar, waterSunset);
    vec3 layered = waterLayerSkyReflection(base, worldNormal, viewDir, waterFar, skyVis);

    return mix(albedo, layered, strength);
}

vec3 waterStylizedHighlights(vec3 lit, vec3 worldPos, vec3 viewNormal,
                             vec3 worldNormal, vec3 viewDir, vec3 sunDir,
                             float skyVis, float frameTime, float strength) {
    if (strength < 0.001) return lit;

    float ribbon = waterSunRibbonMask(worldPos, viewNormal, worldNormal, viewDir,
                                      sunDir, skyVis, frameTime);
    float sparkle = waterMicroSparkle(worldPos, frameTime, ribbon);

    float highlight = ribbon * 0.75 + sparkle;
    return lit + vec3(1.08, 1.00, 0.82) * highlight * strength * 0.85;
}

vec3 applyWaterShading(vec3 albedo, vec3 painterlyLit, vec3 worldPos,
                       vec3 feetPlayerPos, vec3 viewNormal, vec3 worldNormal,
                       vec3 viewDir, vec3 sunDir, vec2 lmcoord,
                       float rainStrength, float frameTime, float waterStrength,
                       float highlightStrength, float distNear, float distFar) {
    float skyVis, blockVis;
    skyVis   = smoothstep(0.02, 0.28, lmcoord.y);
    blockVis = smoothstep(0.02, 0.20, lmcoord.x);

    vec3 paletteAlbedo = waterPaletteAlbedo(albedo, worldPos, feetPlayerPos,
                                            worldNormal, viewDir, sunDir, skyVis,
                                            rainStrength, distNear, distFar,
                                            waterStrength);

    vec3 tintRatio = clamp(
        paletteAlbedo / max(albedo, vec3(0.02)),
        vec3(0.25),
        vec3(2.0)
    );
    vec3 lit = painterlyLit * tintRatio;

    lit = waterStylizedHighlights(lit, worldPos, viewNormal, worldNormal, viewDir,
                                  sunDir, skyVis, frameTime, highlightStrength);

    return mix(painterlyLit, lit, waterStrength);
}
