/*
 * GoldenHaze — Cloud 2.0 (Phase 2.6)
 *
 * Stylized cumulus built from layered shapes, not uniform FBM:
 *   macro blob (70%) + medium blobs (25%) + detail (5%)
 *   flat bottoms, sun-side expansion, hard silhouette / soft interior
 */

float cloudHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloudVnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(cloudHash(i),               cloudHash(i + vec2(1.0, 0.0)), u.x),
               mix(cloudHash(i + vec2(0.0, 1.0)), cloudHash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

// Project view direction onto overhead cloud plane (Ghibli-scale cumulus).
vec2 cloudPlaneUV(vec3 dir, float scale) {
    return dir.xz / max(dir.y, 0.06) * scale;
}

// Macro / medium / detail shape layers — discrete masses, not fuzzy FBM.
void cloudShapeLayers(vec2 cp, out float macro, out float medium, out float detail) {
    macro  = cloudVnoise(cp * 0.14 + vec2(1.7, 4.3));
    medium = cloudVnoise(cp * 0.36 + vec2(8.2, 2.5));
    detail = cloudVnoise(cp * 1.55 + vec2(13.1, 6.7));

    macro  = smoothstep(0.36, 0.58, macro);
    medium = smoothstep(0.40, 0.64, medium);
    detail = detail * 0.5 + 0.5;
}

// Combined density with weighted layers + flat cumulus bottoms.
float stylizedCloudDensity(vec2 cp) {
    float macro, medium, detail;
    cloudShapeLayers(cp, macro, medium, detail);

    float density = macro * 0.70 + medium * 0.25 + detail * 0.05;

    // Bottom clipping: large-scale base height varies slowly across the sky.
    float baseHeight = cloudVnoise(floor(cp * 0.06) * 1.8) * 0.55 + 0.12;
    float heightInCloud = macro - baseHeight;
    density *= smoothstep(0.0, 0.22, heightInCloud);

    return density;
}

// Sun-side expansion: sample slightly sunward for rim lighting reads.
float stylizedCloudDensitySun(vec2 cp, vec3 sunPosition, float expansion) {
    vec2 sunStep = normalize(sunPosition.xz + vec2(0.0, 0.0001)) * expansion;
    return stylizedCloudDensity(cp + sunStep);
}

// Hard outer silhouette + softer interior mass.
float cloudCoverage(float density, float coverageSetting, float horizonFade) {
    float threshold = 1.0 - coverageSetting * 0.78;
    float silhouette = smoothstep(threshold, threshold + 0.06, density);
    float softMass   = smoothstep(threshold - 0.04, threshold + 0.20, density);
    return silhouette * mix(0.85, 1.0, softMass) * horizonFade;
}

// Paint cloud mass with Ghibli lit/shadow split + sunset underside bounce.
vec3 shadeStylizedCloud(vec3 sky, vec2 cp, vec3 sunPosition, vec3 dir,
                        float cover, float day, float sunset, float up,
                        float rainStrength) {
    float density    = stylizedCloudDensity(cp);
    float densitySun = stylizedCloudDensitySun(cp, sunPosition, 0.32);

    float rim   = clamp((density - densitySun) * 4.2, 0.0, 1.0);
    float thick = smoothstep(0.15, 0.88, cover);

    vec3 cloudShadow = mix(vec3(0.06, 0.06, 0.13),
                           vec3(0.45, 0.47, 0.62), day);
    cloudShadow = mix(cloudShadow, vec3(0.45, 0.30, 0.42), sunset * 0.6);

    vec3 cloudLit = mix(vec3(0.07, 0.07, 0.14),
                        vec3(1.10, 1.02, 0.90), day);
    cloudLit = mix(cloudLit, vec3(1.15, 0.62, 0.35), sunset);

    float litFactor = clamp(0.32 + rim * 1.15 * max(day, sunset)
                            - thick * 0.48 + 0.22, 0.0, 1.0);
    vec3 cloudCol = mix(cloudShadow, cloudLit, litFactor);

    vec3 sunsetHorizon = vec3(1.00, 0.45, 0.20);
    cloudCol = mix(cloudCol, sunsetHorizon * 1.1,
                   (1.0 - up) * (1.0 - thick) * 0.5 * max(day, sunset));
    cloudCol = mix(cloudCol, vec3(dot(cloudCol, vec3(0.333))) * 0.5,
                   rainStrength * 0.7);

    return mix(sky, cloudCol, cover * 0.96);
}

// Full cloud pass: returns sky with stylized clouds composited.
vec3 renderStylizedClouds(vec3 sky, vec3 dir, vec3 sunPosition,
                          float coverage, float frameTime,
                          float day, float sunset, float up,
                          float rainStrength) {
    float cloudFade = smoothstep(0.02, 0.12, up);
    if (cloudFade < 0.001) {
        return sky;
    }

    vec2 cp = cloudPlaneUV(dir, 0.9);
    vec2 wind = vec2(frameTime * 0.006, frameTime * 0.0018);
    cp += wind;

    float density = stylizedCloudDensity(cp);
    float cover = cloudCoverage(density, coverage, cloudFade);

    if (cover < 0.002) {
        return sky;
    }

    return shadeStylizedCloud(sky, cp, sunPosition, dir, cover,
                              day, sunset, up, rainStrength);
}
