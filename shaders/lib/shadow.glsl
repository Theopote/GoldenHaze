/*
 * GoldenHaze — stylized shadow mapping (Phase 2.3)
 *
 * Soft, low-frequency sun shadows with cool tinting. Focus is shadow
 * shape and broad penumbra, not PCSS realism.
 */

const int   shadowMapResolution      = 2048;
const float shadowDistanceRenderMul  = 1.0;
const bool  shadowtex0Nearest        = true;
const bool  shadowtex0Mipmaps        = false;

uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

// Distort clip-space XY so nearby texels get more shadow-map resolution.
vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortion = length(shadowClipPos.xy) + 0.10;
    shadowClipPos.xy /= distortion;
    shadowClipPos.z  *= 0.5;
    return shadowClipPos;
}

vec3 shadowScreenPos(vec3 feetPlayerPos, float bias) {
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
    shadowClipPos.z   -= bias;
    shadowClipPos.xyz  = distortShadowClipPos(shadowClipPos.xyz);
    return shadowClipPos.xyz / shadowClipPos.w * 0.5 + 0.5;
}

float shadowMapSample(vec3 shadowScreenPos) {
    if (shadowScreenPos.x < 0.0 || shadowScreenPos.x > 1.0 ||
        shadowScreenPos.y < 0.0 || shadowScreenPos.y > 1.0 ||
        shadowScreenPos.z < 0.0 || shadowScreenPos.z > 1.0) {
        return 1.0;
    }
    float mapDepth = texture2D(shadowtex0, shadowScreenPos.xy).r;
    return step(shadowScreenPos.z, mapDepth);
}

// Wide box-filter PCF — chunky soft edges suited to painted shadows.
float softShadowVisibility(vec3 feetPlayerPos, float bias, float radius) {
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 baseClip = shadowProjection * vec4(shadowViewPos, 1.0);
    baseClip.z   -= bias;
    baseClip.xyz  = distortShadowClipPos(baseClip.xyz);

    float accum = 0.0;
    const int halfRange = 2;
    float invRes = 1.0 / float(shadowMapResolution);

    for (int x = -halfRange; x <= halfRange; x++) {
        for (int y = -halfRange; y <= halfRange; y++) {
            vec2 offset = vec2(float(x), float(y)) * radius * invRes;
            vec4 clipPos = baseClip + vec4(offset * baseClip.w, 0.0, 0.0);
            vec3 screenPos = clipPos.xyz / clipPos.w * 0.5 + 0.5;
            accum += shadowMapSample(screenPos);
        }
    }

    float samples = float((halfRange * 2 + 1) * (halfRange * 2 + 1));
    return accum / samples;
}

// Sun shadow factor in [0,1]: 1 = fully lit, 0 = fully shadowed.
float stylizedSunShadow(vec3 feetPlayerPos, vec3 normal, vec3 sunDir,
                        float skyVis, float strength, float softness) {
    if (skyVis < 0.01 || strength < 0.001) {
        return 1.0;
    }

    // Bias scales with surface slope relative to sun — reduces acne on shallow faces.
    float NdotL = max(dot(normalize(normal), normalize(sunDir)), 0.0);
    float bias  = 0.0006 + (1.0 - NdotL) * 0.0018;

    float lit = softShadowVisibility(feetPlayerPos, bias, softness);
    return mix(1.0, lit, strength * skyVis);
}

// Cool violet-blue tint multiplied into shadowed sun light.
vec3 stylizedShadowTint(float shadowVis) {
    vec3 coolShadow = vec3(0.58, 0.60, 0.82);
    return mix(coolShadow, vec3(1.0), shadowVis);
}
