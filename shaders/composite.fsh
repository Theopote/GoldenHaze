/*
 * composite — semantic bloom bright-pass extract
 *
 * Reads lit scene (colortex0) + GBuffer material (colortex1). Only
 * semantically bright surfaces (sun, sky, water, foliage, emissive)
 * enter bloom — not every high-luma white block.
 */
#version 120

#include "/lib/bloom.glsl"

#define BLOOM_THRESHOLD 0.62 // [0.30 0.40 0.50 0.55 0.62 0.70 0.80]

uniform sampler2D colortex0;
uniform sampler2D colortex1;

varying vec2 texcoord;

/* DRAWBUFFERS:2 */

void main() {
    vec3 scene = texture2D(colortex0, texcoord).rgb;
    float materialId = readMaterialId(texture2D(colortex1, texcoord));

    float mask = semanticBloomMask(scene, materialId, BLOOM_THRESHOLD);

    gl_FragData[0] = vec4(scene * mask, 1.0);
}
