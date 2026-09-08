/*
 * GoldenHaze — painterly atmospheric perspective
 *
 * Distant geometry fades toward a horizon-tinted haze, loses saturation
 * and contrast, and softens — the classic animation-background trick
 * that pushes the world from "game world" toward "painted backdrop".
 */

#include "/lib/gbuffer.glsl"

// View-space depth from Iris depthtex0 ([0,1] hyperbolic depth).
float linearizeDepth(float depth, float nearPlane, float farPlane) {
    float z = depth * 2.0 - 1.0;
    return (2.0 * nearPlane * farPlane) / (farPlane + nearPlane - z * (farPlane - nearPlane));
}

// 0 = near camera, 1 = fully hazed (clamped by strength in the caller).
float computeHaze(float linearDepth, float fogStart, float fogEnd) {
    return smoothstep(fogStart, fogEnd, linearDepth);
}

// Sky-matching distant air color: blue-cyan by day, warmer at sunset,
// deep indigo at night. Rain dulls the tint toward gray.
vec3 atmosphericHorizonColor(vec3 sunPosition, float rainStrength) {
    float sunUp = clamp(normalize(sunPosition).y, -1.0, 1.0);
    float day     = smoothstep(-0.10, 0.25, sunUp);
    float sunset  = (1.0 - abs(sunUp)) * smoothstep(-0.35, 0.05, sunUp);

    vec3 dayHaze    = vec3(0.52, 0.70, 0.88);
    vec3 sunsetHaze = vec3(0.82, 0.62, 0.52);
    vec3 nightHaze  = vec3(0.07, 0.09, 0.17);

    vec3 hazeCol = mix(nightHaze, dayHaze, day);
    hazeCol = mix(hazeCol, sunsetHaze, sunset * 0.75);
    hazeCol = mix(hazeCol, vec3(dot(hazeCol, vec3(0.333))) * 0.65,
                  rainStrength * 0.65);
    return hazeCol;
}

// Material ID from colortex1 alpha (see gbuffer.glsl packGBuffer).
float readMaterialId(vec4 gbuffer) {
    return gbuffer.a * 255.0;
}

bool isSkyMaterial(float materialId) {
    return abs(materialId - MAT_SKY) < 0.5;
}

// Shift toward horizon color, pull saturation down, gently crush contrast.
vec3 applyAtmosphericPerspective(vec3 color, float haze, vec3 horizonColor) {
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color, horizonColor, haze);
    color = mix(vec3(luma), color, 1.0 - haze * 0.35);
    return color;
}

// Cheap 4-tap soften — distant pixels lose blocky texture detail.
vec3 softenDistantDetail(sampler2D sceneTex, vec2 uv, vec2 texelSize,
                         float haze) {
    float radius = haze * 2.5;
    vec2 o = texelSize * radius;
    return (
        texture2D(sceneTex, uv + vec2( o.x,  0.0)).rgb +
        texture2D(sceneTex, uv + vec2(-o.x,  0.0)).rgb +
        texture2D(sceneTex, uv + vec2( 0.0,  o.y)).rgb +
        texture2D(sceneTex, uv + vec2( 0.0, -o.y)).rgb
    ) * 0.25;
}
