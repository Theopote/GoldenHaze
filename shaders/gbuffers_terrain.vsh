/*
 * gbuffers_terrain — world geometry vertex shader
 * Passes through the vanilla lightmap coord (block/sky light) so
 * the fragment shader can use Minecraft's own baked lighting as
 * the basis for the warm color grade, instead of relighting from
 * scratch. Also passes the view-space position (world-stable noise
 * coords for the foliage shimmer) and mc_Entity (block.properties:
 * ID 1 = leaves).
 */
#version 120

attribute int mc_Entity;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 viewPos;
varying float entityId;

void main() {
    gl_Position = ftransform();
    texcoord    = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord     = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;
    viewPos     = (gl_ModelViewMatrix * gl_Vertex).xyz;
    entityId    = float(mc_Entity);
}
