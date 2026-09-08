/*
 * gbuffers_entities_translucent — slimes, translucent mobs (Iris 1.8+).
 */
#version 120

#include "/lib/gbuffers_pass.glsl"

#define PAINTERLY_STRENGTH 1.0
#define PALETTE_STRENGTH   1.0
#define SHADOW_STRENGTH    0.75
#define SHADOW_SOFTNESS    2.5

uniform sampler2D texture;
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
    if (albedo.a < 0.02) discard;

    writeEntityGbuffer(albedo.rgb, albedo.a, viewNormal, worldNormal, lmcoord, feetPlayerPos,
                         sunPosition, rainStrength,
                         PALETTE_STRENGTH, PAINTERLY_STRENGTH,
                         SHADOW_STRENGTH, SHADOW_SOFTNESS);
}
