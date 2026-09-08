/*
 * final — combine + warm color grade (Phase 2.9 retune)
 *
 * 1. Applies painterly atmospheric perspective to the scene (depthtex0).
 * 2. Adds restrained bloom (colortex2) and god rays (colortex3) as accents.
 * 3. Split-tones, tonemap, vignette, fixed screen-space paper grain.
 *
 * DEBUG_VIEW 1–8 visualize GBuffer / depth / lighting proxies for tuning.
 */
#version 120

#include "/lib/atmospheric.glsl"
#include "/lib/debug.glsl"

#define DEBUG_VIEW          0    // [0 1 2 3 4 5 6 7 8]
#define BLOOM_STRENGTH        0.50 // [0.00 0.20 0.40 0.50 0.60 0.80 1.00 1.30]
#define GODRAY_STRENGTH       0.32 // [0.00 0.20 0.32 0.45 0.60 0.90 1.20 1.60]
#define WARMTH                0.85 // [0.00 0.30 0.60 0.85 1.00 1.40 1.80]
#define VIGNETTE_STRENGTH     0.42 // [0.00 0.20 0.40 0.42 0.60 0.80 1.00]
#define GRAIN_STRENGTH        0.25 // [0.00 0.20 0.25 0.35 0.60 1.00 1.50]
#define CHROMA_STRENGTH       0.0  // [0.00 0.30 0.60 1.00 1.50] optional cinematic
#define ATMOSPHERE_STRENGTH   1.0  // [0.00 0.50 0.75 1.00 1.25 1.50]
#define ATMOSPHERE_START     24.0  // [8 16 24 32 48 64 96]
#define ATMOSPHERE_END      160.0  // [80 120 160 200 256 320 480]
// Shared option anchors (also defined in gbuffers passes; Iris scans all programs)
#define SUN_STRENGTH        1.0  // [0.00 0.50 0.75 1.00 1.25 1.50]
#define SKY_STRENGTH        0.85 // [0.00 0.40 0.65 0.85 1.00 1.25]
#define BOUNCE_STRENGTH     0.35 // [0.00 0.15 0.25 0.35 0.50 0.75]
#define PALETTE_STRENGTH    1.0  // [0.00 0.25 0.50 0.75 1.00]
#define WATER_STRENGTH      1.0  // [0.00 0.25 0.50 0.75 1.00]
#define WATER_DIST_NEAR     4.0  // [2.0 4.0 8.0 12.0 16.0]
#define WATER_DIST_FAR     40.0  // [24.0 40.0 64.0 96.0 128.0]

uniform sampler2D colortex0;
uniform sampler2D colortex1; // GBuffer: normal + material (sky mask)
uniform sampler2D colortex2; // blurred bloom
uniform sampler2D colortex3; // god-ray accumulation
uniform sampler2D depthtex0;
uniform sampler2D canvas;
uniform vec3 sunPosition;
uniform float near;
uniform float far;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

vec3 warmGrade(vec3 color) {
    vec3 shadeShift = vec3(0.05, 0.03, 0.08) * WARMTH;
    vec3 highShift  = vec3(0.12, 0.07, -0.02) * WARMTH;

    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color += mix(shadeShift, highShift, smoothstep(0.2, 0.8, luma));

    color = mix(vec3(luma), color, 1.0 + 0.10 * WARMTH);
    return color;
}

vec3 tonemap(vec3 x) {
    return x / (x + vec3(0.65));
}

vec3 softCurve(vec3 x) {
    return x * (0.93 + 0.07 * x) + vec3(0.022);
}

void main() {
    vec2 fromCenter = texcoord - 0.5;
    vec2 caOffset = fromCenter * (CHROMA_STRENGTH * 0.0015)
                  * dot(fromCenter, fromCenter) * 4.0;
    vec3 scene;
    scene.r = texture2D(colortex0, texcoord + caOffset).r;
    scene.g = texture2D(colortex0, texcoord).g;
    scene.b = texture2D(colortex0, texcoord - caOffset).b;

    vec4 gbuffer = texture2D(colortex1, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;
    float linearZ = linearizeDepth(depth, near, far);
    float haze = computeHaze(linearZ, ATMOSPHERE_START, ATMOSPHERE_END);

    float materialId = readMaterialId(gbuffer);
    if (isSkyMaterial(materialId)) {
        haze = 0.0;
    }

    haze *= ATMOSPHERE_STRENGTH;

    if (haze > 0.001) {
        vec2 texelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);
        vec3 softened = softenDistantDetail(colortex0, texcoord, texelSize, haze);
        scene = mix(scene, softened, haze * 0.55);

        vec3 horizonColor = atmosphericHorizonColor(sunPosition, rainStrength);
        scene = applyAtmosphericPerspective(scene, haze, horizonColor);
    }

#if DEBUG_VIEW != 0
    vec3 bloomExtract = texture2D(colortex2, texcoord).rgb;
    vec3 dbg = applyDebugView(DEBUG_VIEW, scene, gbuffer, depth, linearZ,
                              haze, bloomExtract, sunPosition);
    gl_FragColor = vec4(dbg, 1.0);
    return;
#endif

    vec3 bloom  = texture2D(colortex2, texcoord).rgb;
    vec3 shafts = texture2D(colortex3, texcoord).rgb;

    float weatherFade = 1.0 - rainStrength * 0.55;
    vec3 color = scene
               + bloom  * BLOOM_STRENGTH  * weatherFade
               + shafts * GODRAY_STRENGTH * weatherFade;
    color = tonemap(color);
    color = softCurve(color);
    color = warmGrade(color);

    vec2 uv = texcoord - 0.5;
    float vignette = 1.0 - dot(uv, uv) * VIGNETTE_STRENGTH;
    color *= vignette;

    vec2 res = vec2(viewWidth, viewHeight);
    float g1 = texture2D(canvas, texcoord * res / 256.0).r;
    float g2 = texture2D(canvas, texcoord * res / 512.0).r;
    float grain = (g1 * 0.65 + g2 * 0.35) - 0.5;
    float luma2 = dot(color, vec3(0.299, 0.587, 0.114));
    color += grain * 0.035 * GRAIN_STRENGTH * (1.0 - luma2 * 0.55);

    gl_FragColor = vec4(color, 1.0);
}
