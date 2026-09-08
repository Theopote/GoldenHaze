#version 120

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 worldPos;
varying vec3 feetPlayerPos;
varying vec3 viewNormal;
varying vec3 worldNormal;
varying vec3 viewDir;

void main() {
    gl_Position = ftransform();
    texcoord    = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord     = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    worldPos      = feetPlayerPos + cameraPosition;
    viewNormal        = normalize(gl_NormalMatrix * gl_Normal);
    worldNormal   = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    // World-space surface → camera (to-camera). Used for Fresnel with worldNormal.
    viewDir       = normalize(cameraPosition - worldPos);
}
