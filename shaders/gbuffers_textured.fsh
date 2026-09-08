/*
 * gbuffers_textured — unlit particles, world border, some effects.
 */
#version 120

#include "/lib/gbuffers_pass.glsl"

uniform sampler2D texture;
uniform vec3 sunPosition;
uniform float rainStrength;

varying vec2 texcoord;
varying vec4 vertexColor;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.05) discard;

    writeUnlitGbuffer(albedo.rgb, albedo.a, vec3(0.0, 0.0, 1.0), MAT_DEFAULT,
                      sunPosition, rainStrength);
}
