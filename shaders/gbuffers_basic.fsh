#version 120

#include "/lib/painterly.glsl"

#define PAINTERLY_STRENGTH 1.0
#define SHADOW_STRENGTH    1.0
#define SHADOW_SOFTNESS    2.5

uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform float rainStrength;

varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 viewNormal;
varying vec3 worldNormal;
varying vec3 feetPlayerPos;

/* DRAWBUFFERS:01 */

void main() {
    vec3 vanillaLight = texture2D(lightmap, lmcoord).rgb;
    vec3 litColor = shadePainterly(vertexColor.rgb, viewNormal, worldNormal, sunPosition,
                                   lmcoord, vanillaLight, MAT_DEFAULT, rainStrength,
                                   PAINTERLY_STRENGTH, feetPlayerPos,
                                   SHADOW_STRENGTH, SHADOW_SOFTNESS);

    gl_FragData[0] = vec4(litColor, vertexColor.a);
    gl_FragData[1] = packGBuffer(viewNormal, MAT_DEFAULT);
}
