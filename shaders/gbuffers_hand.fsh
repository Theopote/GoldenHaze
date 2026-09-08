/*
 * gbuffers_hand — first-person hand and held items.
 */
#version 120

#include "/lib/gbuffers_pass.glsl"

#define PAINTERLY_STRENGTH 1.0 // [0.00 0.25 0.50 0.75 1.00]
#define PALETTE_STRENGTH   1.0 // [0.00 0.25 0.50 0.75 1.00]
#define SHADOW_STRENGTH    0.0  // hand is too close for stable shadow map
#define SHADOW_SOFTNESS    2.5 // [1.0 1.5 2.0 2.5 3.5 5.0]

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform float rainStrength;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 viewNormal;
varying vec3 worldNormal;
varying vec3 feetPlayerPos;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.1) discard;

    writeEntityGbuffer(albedo.rgb, albedo.a, viewNormal, worldNormal, lmcoord, feetPlayerPos,
                         sunPosition, rainStrength,
                         PALETTE_STRENGTH, PAINTERLY_STRENGTH,
                         SHADOW_STRENGTH, SHADOW_SOFTNESS);
}
