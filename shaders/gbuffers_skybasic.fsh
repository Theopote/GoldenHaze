/*
 * gbuffers_skybasic — painterly sky gradient + procedural clouds
 *
 * Replaces the vanilla sky dome with:
 *   1. a vertical gradient driven by sun height (sunPosition.y):
 *      day = warm golden horizon -> soft blue zenith,
 *      sunset = saturated orange band, night = deep indigo.
 *   2. big soft fbm clouds: the view direction is projected onto an
 *      imaginary overhead plane and shaded with 5-octave value noise.
 *      A second noise sample shifted toward the sun gives cheap
 *      sun-lit rims ("gold lining"), and cloud bottoms pick up a warm
 *      bounce near the horizon. Clouds drift with frameTimeCounter.
 *
 * The horizon band and sun-lit cloud rims are picked up by the
 * composite-stage bright-pass extract from colortex0. Clouds fade out
 * near the horizon (haze) and at night they become dark silhouettes.
 *
 * vs gbuffers_basic: "basic" covers untextured world geometry
 * (leash, beacon beam...). The sky dome goes through skybasic.
 */
#version 120

#include "/lib/gbuffer.glsl"

#define ENABLE_CLOUDS // toggle in the shader options GUI
#define CLOUD_COVERAGE 0.45 // [0.25 0.35 0.45 0.55 0.65]

uniform vec3 sunPosition;      // view-space direction toward the sun
uniform float rainStrength;    // 0..1, dull the sky when it rains
uniform float frameTimeCounter;// seconds, drives cloud drift

varying vec3 viewDir;
varying vec3 normal;

/* DRAWBUFFERS:01 */

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),               hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * vnoise(p);
        p  = p * 2.03 + vec2(19.7, 7.3);
        a *= 0.5;
    }
    return v;
}

// large-scale cloud density with domain warp: warping the sample
// position by another fbm makes noise blobs clump into big rounded
// cumulus puffs instead of uniform fuzz
float cloudDensity(vec2 p) {
    vec2 warp = vec2(fbm(p * 0.35 + vec2(5.2, 1.3)),
                     fbm(p * 0.35 + vec2(8.1, 9.7))) * 1.4;
    float n = fbm(p * 0.55 + warp);
    // bias toward discrete blobs: push mid values down so clouds
    // separate into distinct masses with clean sky between them
    return n * 1.25 - 0.12;
}

void main() {
    vec3  dir   = normalize(viewDir);
    float up    = dir.y;
    float sunUp = clamp(normalize(sunPosition).y, -1.0, 1.0);

    float day     = smoothstep(-0.10, 0.25, sunUp);
    float sunset  = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);
    float horizon = exp(-max(up, 0.0) * 3.0);

    // palettes: {zenith, horizon}
    vec3 dayZenith    = vec3(0.36, 0.56, 0.92);
    vec3 dayHorizon   = vec3(1.00, 0.83, 0.55);
    vec3 sunsetZenith = vec3(0.25, 0.22, 0.45);
    vec3 sunsetHorizon= vec3(1.00, 0.45, 0.20);
    vec3 nightZenith  = vec3(0.02, 0.03, 0.08);
    vec3 nightHorizon = vec3(0.05, 0.05, 0.12);

    vec3 zenithCol  = mix(nightZenith,  dayZenith,  day);
    vec3 horizonCol = mix(nightHorizon, dayHorizon, day);
    zenithCol  = mix(zenithCol,  sunsetZenith,  sunset * 0.7);
    horizonCol = mix(horizonCol, sunsetHorizon, sunset);

    vec3 sky = mix(zenithCol, horizonCol, horizon);
    sky = mix(sky, vec3(dot(sky, vec3(0.333))) * 0.6, rainStrength * 0.7);

#ifdef ENABLE_CLOUDS
    // clouds only live above the horizon; fade them into the haze band
    float cloudFade = smoothstep(0.02, 0.12, up);
    if (cloudFade > 0.001) {
        // project the view dir onto an imaginary cloud plane overhead;
        // the 0.35 scale makes cloud masses big (Ghibli cumulus)
        vec2 cp   = dir.xz / max(up, 0.06) * 0.9;
        vec2 wind = vec2(frameTimeCounter * 0.006,
                         frameTimeCounter * 0.0018);
        float n = cloudDensity(cp + wind);

        // soft, wide coverage ramp -> rounded puffy edges, and a
        // flatter bottom: bias density down near the cloud base so
        // undersides flatten like real cumulus
        float cover = smoothstep(1.0 - CLOUD_COVERAGE * 0.8,
                                 1.45 - CLOUD_COVERAGE * 0.8, n);
        cover *= cloudFade;

        if (cover > 0.002) {
            // volume shading: a second density read slightly sunward
            // approximates light passing through the cloud — rims
            // facing the sun catch light, cores stay in cool shadow
            vec2  sunStep  = normalize(sunPosition.xz + vec2(0.0, 0.0001)) * 0.25;
            float nSun     = cloudDensity(cp + wind + sunStep);
            float rim      = clamp((n - nSun) * 4.0, -1.0, 1.0);
            float thick    = smoothstep(0.1, 0.9, cover); // core vs edge

            // Ghibli palette: big value gap between cool gray-violet
            // shadow and warm cream lit side; sunset stains the
            // undersides gold-red
            vec3 cloudShadow = mix(vec3(0.06, 0.06, 0.13),
                                   vec3(0.45, 0.47, 0.62), day);
            cloudShadow = mix(cloudShadow, vec3(0.45, 0.30, 0.42), sunset * 0.6);
            vec3 cloudLit = mix(vec3(0.07, 0.07, 0.14),
                                vec3(1.10, 1.02, 0.90), day);
            cloudLit = mix(cloudLit, vec3(1.15, 0.62, 0.35), sunset);

            // thick cores read as shadow regardless of rim; edges
            // and sun-facing sides go bright
            float litFactor = clamp(0.35 + rim * 1.1 * max(day, sunset)
                                    - thick * 0.5 + 0.25, 0.0, 1.0);
            vec3 cloudCol = mix(cloudShadow, cloudLit, litFactor);

            // golden under-lighting at sunset / warm horizon bounce
            cloudCol = mix(cloudCol, sunsetHorizon * 1.1,
                           (1.0 - up) * (1.0 - thick) * 0.5 * max(day, sunset));
            cloudCol = mix(cloudCol, vec3(dot(cloudCol, vec3(0.333))) * 0.5,
                           rainStrength * 0.7);

            sky = mix(sky, cloudCol, cover * 0.95);
        }
    }
#endif

    gl_FragData[0] = vec4(sky, 1.0);
    gl_FragData[1] = packGBuffer(normal, MAT_SKY);
}
