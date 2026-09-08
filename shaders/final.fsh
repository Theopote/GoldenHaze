/*
 * final — combine + warm color grade
 *
 * 1. Applies painterly atmospheric perspective to the scene (depthtex0).
 * 2. Adds blurred bloom (colortex2) and god rays (colortex3).
 * 3. Split-tones, tonemap, vignette, fixed screen-space paper grain.
 */
#version 120

#include "/lib/atmospheric.glsl"

#define BLOOM_STRENGTH        0.8  // [0.00 0.20 0.40 0.60 0.80 1.00 1.30 1.60]
#define GODRAY_STRENGTH       0.45 // [0.00 0.30 0.45 0.60 0.90 1.20 1.60 2.00]
#define WARMTH                1.0  // [0.00 0.30 0.60 1.00 1.40 1.80]
#define VIGNETTE_STRENGTH     0.6  // [0.00 0.20 0.40 0.60 0.80 1.00]
#define GRAIN_STRENGTH        0.35 // [0.00 0.30 0.35 0.60 1.00 1.50]
#define CHROMA_STRENGTH       0.0  // [0.00 0.30 0.60 1.00 1.50] optional cinematic
#define ATMOSPHERE_STRENGTH   1.0  // [0.00 0.50 0.75 1.00 1.25 1.50]
#define ATMOSPHERE_START     24.0  // [8 16 24 32 48 64 96]
#define ATMOSPHERE_END      160.0  // [80 120 160 200 256 320 480]

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
    vec3 shadowTint    = vec3(0.05, 0.03, 0.08) * WARMTH;
    vec3 highlightTint = vec3(0.12, 0.07, -0.02) * WARMTH;

    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color += mix(shadowTint, highlightTint, smoothstep(0.2, 0.8, luma));

    color = mix(vec3(luma), color, 1.0 + 0.15 * WARMTH);
    return color;
}

vec3 tonemap(vec3 x) {
    return x / (x + vec3(0.6));
}

vec3 softCurve(vec3 x) {
    return x * (0.92 + 0.08 * x) + vec3(0.028);
}

void main() {
    vec2 fromCenter = texcoord - 0.5;
    vec2 caOffset = fromCenter * (CHROMA_STRENGTH * 0.0015)
                  * dot(fromCenter, fromCenter) * 4.0;
    vec3 scene;
    scene.r = texture2D(colortex0, texcoord + caOffset).r;
    scene.g = texture2D(colortex0, texcoord).g;
    scene.b = texture2D(colortex0, texcoord - caOffset).b;

    // --- atmospheric perspective (Phase 2.1) ---
    float depth = texture2D(depthtex0, texcoord).r;
    float linearZ = linearizeDepth(depth, near, far);
    float haze = computeHaze(linearZ, ATMOSPHERE_START, ATMOSPHERE_END);

    float materialId = readMaterialId(texture2D(colortex1, texcoord));
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

    vec3 bloom  = texture2D(colortex2, texcoord).rgb;
    vec3 shafts = texture2D(colortex3, texcoord).rgb;

    vec3 color = scene + bloom * BLOOM_STRENGTH + shafts * GODRAY_STRENGTH;
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
    color += grain * 0.05 * GRAIN_STRENGTH * (1.0 - luma2 * 0.6);

    gl_FragColor = vec4(color, 1.0);
}
