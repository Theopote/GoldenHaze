/*
 * gbuffers_weather — rain and snow layers (not particle-based weather).
 */
#version 120

#include "/lib/gbuffers_pass.glsl"

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
    if (albedo.a < 0.02) discard;

    writeWeatherGbuffer(albedo.rgb, albedo.a * vertexColor.a, lmcoord, normal,
                        sunPosition, rainStrength);
}
