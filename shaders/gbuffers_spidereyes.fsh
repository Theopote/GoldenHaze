/*
 * gbuffers_spidereyes — spider, enderman, dragon eyes.
 */
#version 120

#include "/lib/gbuffers_pass.glsl"

uniform sampler2D texture;
uniform vec3 sunPosition;

varying vec2 texcoord;
varying vec4 vertexColor;
varying vec3 viewNormal;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.05) discard;

    writeSpiderEyesGbuffer(albedo.rgb, albedo.a, viewNormal, sunPosition);
}
