/*
 * gbuffers_skytextured — sun / moon / stars
 *
 * The vanilla sun and moon are textured quads drawn by this pass.
 * We warm-tint them and write the sun disc into colortex1 with a
 * strong boost, so:
 *   1. the bloom pass gives the sun a proper halo, and
 *   2. the god-ray pass (composite2) has a bright "source" to
 *      radiate from when sampling toward the sun's screen position.
 * Without this file the sun/moon fall back to the vanilla fixed
 * pipeline and never reach colortex1.
 */
#version 120

uniform sampler2D texture;
uniform vec3 sunPosition;
uniform float rainStrength;

varying vec2 texcoord;
varying vec4 vertexColor;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.1) discard;

    float sunUp = clamp(normalize(sunPosition).y, -1.0, 1.0);
    float day   = smoothstep(-0.10, 0.25, sunUp);

    // warm golden disc during the day, pale and dim at night (moon)
    vec3 tint = mix(vec3(0.55, 0.60, 0.75), vec3(1.00, 0.85, 0.55), day);
    vec3 color = albedo.rgb * tint;
    color = mix(color, vec3(0.35), rainStrength * 0.6);

    gl_FragData[0] = vec4(color, albedo.a);

    // strong bright-pass feed: sun ~2.5 (HDR), moon/stars modest
    float feed = mix(0.4, 2.5, day);
    gl_FragData[1] = vec4(color * feed * (1.0 - rainStrength), albedo.a);
}
