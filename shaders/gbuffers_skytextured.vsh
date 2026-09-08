/*
 * gbuffers_skytextured — sun / moon / stars vertex shader
 * Plain textured passthrough; all the interesting work is in the
 * fragment shader (boosting the sun disc into the bloom buffer).
 */
#version 120

varying vec2 texcoord;
varying vec4 vertexColor;
varying vec3 normal;

void main() {
    gl_Position = ftransform();
    texcoord    = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
    normal      = normalize(gl_NormalMatrix * gl_Normal);
}
