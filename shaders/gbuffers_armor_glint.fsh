/*
 * gbuffers_armor_glint — enchantment shimmer on armor and held items.
 */
#version 120

#include "/lib/gbuffers_pass.glsl"

#define PAINTERLY_STRENGTH 0.5 // [0.00 0.25 0.50 0.75 1.00]
#define SHADOW_STRENGTH    0.0  // overlay pass
#define SHADOW_SOFTNESS    2.5 // [1.0 1.5 2.0 2.5 3.5 5.0]

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform float rainStrength;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 normal;
varying vec3 feetPlayerPos;

/* DRAWBUFFERS:01 */

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.05) discard;

    writeArmorGlintGbuffer(albedo.rgb, albedo.a, normal, lmcoord, feetPlayerPos,
                            sunPosition, rainStrength,
                            PAINTERLY_STRENGTH, SHADOW_STRENGTH, SHADOW_SOFTNESS);
}
