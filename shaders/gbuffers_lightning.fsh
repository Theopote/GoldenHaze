/*
 * gbuffers_lightning — lightning bolts, ender dragon death beams (Iris 1.8+).
 */
#version 120

#include "/lib/gbuffers_pass.glsl"

uniform sampler2D texture;
uniform vec3 sunPosition;

varying vec2 texcoord;
varying vec4 vertexColor;
varying vec3 viewNormal;
varying vec3 feetPlayerPos;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.02) discard;

    writeLightningGbuffer(albedo.rgb, albedo.a, viewNormal, sunPosition);
}
