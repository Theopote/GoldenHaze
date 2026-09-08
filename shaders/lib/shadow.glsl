/*
 * GoldenHaze — stylized shadow mapping (Phase 2.3)
 *
 * Soft, low-frequency sun occlusion with cool shading. Focus is
 * shape and broad penumbra, not PCSS realism.
 *
 * Note: avoid identifiers named exactly "tint" (Iris Sodium injects
 * a varying with that name) and avoid parameter names that match
 * function names (breaks some Iris glsl-transformer paths).
 */

#ifndef GOLDENHAZE_SHADOW
#define GOLDENHAZE_SHADOW

const int   shadowMapResolution      = 1024;
const float shadowDistanceRenderMul  = 1.0;
const bool  shadowtex0Nearest        = true;
const bool  shadowtex0Mipmaps        = false;

uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

vec3 distortShadowClipPos(vec3 clipPos) {
    float distortion = length(clipPos.xy) + 0.10;
    clipPos.xy /= distortion;
    clipPos.z  *= 0.5;
    return clipPos;
}

vec3 ghToShadowScreen(vec3 feetPlayerPos, float bias) {
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 clipPos = shadowProjection * vec4(shadowViewPos, 1.0);
    clipPos.z   -= bias;
    clipPos.xyz  = distortShadowClipPos(clipPos.xyz);
    return clipPos.xyz / clipPos.w * 0.5 + 0.5;
}

float ghSampleShadowMap(vec3 screenPos) {
    if (screenPos.x < 0.0 || screenPos.x > 1.0 ||
        screenPos.y < 0.0 || screenPos.y > 1.0 ||
        screenPos.z < 0.0 || screenPos.z > 1.0) {
        return 1.0;
    }
    float mapDepth = texture2D(shadowtex0, screenPos.xy).r;
    return step(screenPos.z, mapDepth);
}

float softShadowVisibility(vec3 feetPlayerPos, float bias, float radius) {
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 baseClip = shadowProjection * vec4(shadowViewPos, 1.0);
    baseClip.z   -= bias;
    baseClip.xyz  = distortShadowClipPos(baseClip.xyz);

    float accum = 0.0;
    const int halfRange = 1;
    float invRes = 1.0 / float(shadowMapResolution);

    for (int x = -halfRange; x <= halfRange; x++) {
        for (int y = -halfRange; y <= halfRange; y++) {
            vec2 offset = vec2(float(x), float(y)) * radius * invRes;
            vec4 clipPos = baseClip + vec4(offset * baseClip.w, 0.0, 0.0);
            vec3 screenPos = clipPos.xyz / clipPos.w * 0.5 + 0.5;
            accum += ghSampleShadowMap(screenPos);
        }
    }

    float samples = float((halfRange * 2 + 1) * (halfRange * 2 + 1));
    return accum / samples;
}

// Sun occlusion factor in [0,1]: 1 = fully lit, 0 = fully occluded.
float ghMapSunLit(vec3 feetPlayerPos, vec3 viewNormal, vec3 lightDir,
                  float skyVis, float strength, float softness) {
    if (skyVis < 0.01 || strength < 0.001) {
        return 1.0;
    }

    float NdotL = max(dot(normalize(viewNormal), normalize(lightDir)), 0.0);
    float bias  = 0.0006 + (1.0 - NdotL) * 0.0018;

    float lit = softShadowVisibility(feetPlayerPos, bias, softness);
    return mix(1.0, lit, strength * skyVis);
}

vec3 ghShadeMul(float litVis) {
    vec3 coolShade = vec3(0.58, 0.60, 0.82);
    return mix(coolShade, vec3(1.0), litVis);
}

#endif
