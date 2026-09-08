/*
 * gbuffers_skybasic — sky dome vertex shader
 * This pass renders the vanilla sky gradient dome (no sun/moon/stars
 * geometry — those are gbuffers_skytextured). We pass the view-space
 * direction down so the fragment shader can build the gradient and
 * project the procedural cloud plane from it.
 */
#version 120

varying vec3 viewDir;
varying vec3 normal;

void main() {
    gl_Position = ftransform();
    viewDir     = (gl_ModelViewMatrix * gl_Vertex).xyz;
    normal      = normalize(viewDir);
}
