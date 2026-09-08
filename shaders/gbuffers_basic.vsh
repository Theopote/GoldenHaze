#version 120

uniform mat4 gbufferModelViewInverse;

varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 normal;
varying vec3 feetPlayerPos;

void main() {
    gl_Position = ftransform();
    lmcoord     = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;
    normal      = normalize(gl_NormalMatrix * gl_Normal);

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}
