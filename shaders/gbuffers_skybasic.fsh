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
 * The horizon band and sun-lit cloud rims feed colortex1 so the bloom
 * picks them up. Clouds fade out near the horizon (haze) and at night
 * they become dark silhouettes.
 *
 * vs gbuffers_basic: "basic" covers untextured world geometry
 * (leash, beacon beam...). The sky dome goes through skybasic.
 */
#version 120

#define ENABLE_CLOUDS // toggle in the shader options GUI
#define CLOUD_COVERAGE 0.55 // [0.35 0.45 0.55 0.65 0.75]

uniform vec3 sunPosition;      // view-space direction toward the sun
uniform float rainStrength;    // 0..1, dull the sky when it rains
uniform float frameTimeCounter;// seconds, drives cloud drift

varying vec3 viewDir;

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

    vec3 cloudGlowCol = vec3(0.0);
    float cloudGlow   = 0.0;

#ifdef ENABLE_CLOUDS
    // clouds only live above the horizon; fade them into the haze band
    float cloudFade = smoothstep(0.03, 0.18, up);
    if (cloudFade > 0.001) {
        // project the view dir onto an imaginary cloud plane overhead
        vec2 cp   = dir.xz / max(up, 0.05) * 1.6;
        vec2 wind = vec2(frameTimeCounter * 0.008,
                         frameTimeCounter * 0.0025);
        float n = fbm(cp * 0.9 + wind);

        float cover = smoothstep(0.75 - CLOUD_COVERAGE,
                                 1.25 - CLOUD_COVERAGE, n);
        cover *= cloudFade;

        if (cover > 0.001) {
            // sun-lit rims: resample the noise shifted sunward; where
            // density drops off toward the sun, the rim lights up
            vec2  sunStep = normalize(sunPosition.xz + vec2(0.0, 1e-4)) * 0.18;
            float rim = clamp((n - fbm(cp * 0.9 + wind + sunStep)) * 6.0,
                              -1.0, 1.0);

            // cloud palette: cool gray-violet shadow, warm gold lit side
            vec3 cloudShadow = mix(vec3(0.05, 0.05, 0.10),
                                   vec3(0.52, 0.55, 0.68), day);
            cloudShadow = mix(cloudShadow, vec3(0.40, 0.30, 0.45), sunset * 0.5);
            vec3 cloudLit = mix(vec3(0.06, 0.06, 0.12),
                                vec3(1.05, 0.95, 0.82), day);
            cloudLit = mix(cloudLit, vec3(1.10, 0.55, 0.30), sunset);

            float litFactor = clamp(0.55 + rim * 0.9 * max(day, sunset), 0.0, 1.0);
            vec3 cloudCol = mix(cloudShadow, cloudLit, litFactor);

            // warm bounce on cloud bottoms near the horizon
            cloudCol = mix(cloudCol, horizonCol * 1.05,
                           (1.0 - up) * 0.35 * max(day, sunset));
            cloudCol = mix(cloudCol, vec3(dot(cloudCol, vec3(0.333))) * 0.5,
                           rainStrength * 0.7);

            sky = mix(sky, cloudCol, cover * 0.92);

            // sun-facing rims glow a little into the bloom buffer
            cloudGlowCol = cloudCol;
            cloudGlow    = cover * max(rim, 0.0) * max(day, sunset) * 0.6;
        }
    }
#endif

    gl_FragData[0] = vec4(sky, 1.0);

    // bloom feed: horizon band glows (sun halo), zenith barely, plus rims
    float glow = horizon * mix(0.10, 0.55, max(day, sunset)) + 0.03 * day;
    gl_FragData[1] = vec4(sky * glow * (1.0 - rainStrength * 0.8)
                          + cloudGlowCol * cloudGlow, 1.0);
}
