/*
 * gbuffers_terrain — world geometry vertex shader
 * Passes through the vanilla lightmap coord (block/sky light) so
 * the fragment shader can use Minecraft's own baked lighting as
 * the basis for the warm color grade, instead of relighting from
 * scratch. Also passes world-space position (world-stable noise
 * coords for the foliage shimmer) and mc_Entity (block.properties:
 * ID 1 = leaves). mc_Entity is declared float here — Iris fills it
 * with the integer ID and does the conversion for us; declaring it
 * int trips a transformer bug that drops the varying assignment.
 */
#version 120

attribute float mc_Entity;

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 worldPos;
varying vec3 feetPlayerPos;
varying vec3 normal;
varying vec3 worldNormal;
varying float blockId; // renamed from entityId: that name collides
                       // with an Iris-internal declaration and breaks
                       // unrelated passes (text_be) at link time

void main() {
    gl_Position = ftransform();
    texcoord    = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord     = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    worldPos      = feetPlayerPos + cameraPosition;
    normal        = normalize(gl_NormalMatrix * gl_Normal);
    worldNormal   = normalize(mat3(gbufferModelViewInverse) * normal);
    blockId       = mc_Entity;
}
