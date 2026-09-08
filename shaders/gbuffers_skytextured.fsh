/*
 * gbuffers_skytextured — sun / moon / stars
 *
 * Warm-tints the vanilla sun/moon quads. Scene color is written bright
 * enough for the composite-stage bloom extract to build a proper halo.
 */
#version 120

#include "/lib/gbuffer.glsl"

uniform sampler2D texture;
uniform vec3 sunPosition;
uniform float rainStrength;

varying vec2 texcoord;
varying vec4 vertexColor;
varying vec3 normal;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.1) discard;

    float sunUp = clamp(normalize(sunPosition).y, -1.0, 1.0);
    float day   = smoothstep(-0.10, 0.25, sunUp);

    vec3 tint = mix(vec3(0.55, 0.60, 0.75), vec3(1.00, 0.85, 0.55), day);
    vec3 color = albedo.rgb * tint;
    color = mix(color, vec3(0.35), rainStrength * 0.6);

    // HDR headroom for bloom extract (was previously a separate buffer feed)
    float feed = mix(0.4, 2.5, day);
    color *= feed * (1.0 - rainStrength);

    gl_FragData[0] = vec4(color, albedo.a);
    gl_FragData[1] = packGBuffer(normal, MAT_SKY);
}
