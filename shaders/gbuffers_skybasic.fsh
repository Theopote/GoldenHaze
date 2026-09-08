/*
 * gbuffers_skybasic — painterly sky gradient + Cloud 2.0
 *
 * Sky gradient (zenith / horizon / sunset / night) plus stylized
 * cumulus from lib/cloud.glsl — macro shape hierarchy, not FBM fuzz.
 */
#version 120

#include "/lib/gbuffer.glsl"
#include "/lib/cloud.glsl"

#define ENABLE_CLOUDS // toggle in the shader options GUI
#define CLOUD_COVERAGE 0.45 // [0.25 0.35 0.45 0.55 0.65]

uniform vec3 sunPosition;
uniform float rainStrength;
uniform float frameTimeCounter;

varying vec3 viewDir;
varying vec3 viewNormal;

/* DRAWBUFFERS:01 */

void main() {
    vec3 dir    = normalize(viewDir);
    float up    = dir.y;
    float sunUp = clamp(normalize(sunPosition).y, -1.0, 1.0);

    float day     = smoothstep(-0.10, 0.25, sunUp);
    float sunset  = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);
    float horizon = exp(-max(up, 0.0) * 3.0);

    vec3 dayZenith     = vec3(0.36, 0.56, 0.92);
    vec3 dayHorizon    = vec3(1.00, 0.83, 0.55);
    vec3 sunsetZenith  = vec3(0.25, 0.22, 0.45);
    vec3 sunsetHorizon = vec3(1.00, 0.45, 0.20);
    vec3 nightZenith   = vec3(0.02, 0.03, 0.08);
    vec3 nightHorizon  = vec3(0.05, 0.05, 0.12);

    vec3 zenithRgb  = mix(nightZenith,  dayZenith,  day);
    vec3 horizonRgb = mix(nightHorizon, dayHorizon, day);
    zenithRgb  = mix(zenithRgb,  sunsetZenith,  sunset * 0.7);
    horizonRgb = mix(horizonRgb, sunsetHorizon, sunset);

    vec3 sky = mix(zenithRgb, horizonRgb, horizon);
    sky = mix(sky, vec3(dot(sky, vec3(0.333))) * 0.6, rainStrength * 0.7);

#ifdef ENABLE_CLOUDS
    sky = renderStylizedClouds(sky, dir, sunPosition, CLOUD_COVERAGE,
                               frameTimeCounter, day, sunset, up, rainStrength);
#endif

    gl_FragData[0] = vec4(sky, 1.0);
    gl_FragData[1] = packGBuffer(viewNormal, MAT_SKY);
}
