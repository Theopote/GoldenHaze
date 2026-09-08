/*
 * composite — bloom bright-pass extract
 *
 * Reads the lit scene (colortex0) and writes thresholded highlights
 * to colortex2. composite1/composite2 blur colortex2; composite3
 * god-rays sample the blurred result. colortex1 (GBuffer) is untouched.
 */
#version 120

#define BLOOM_THRESHOLD 0.62 // [0.30 0.40 0.50 0.55 0.62 0.70 0.80]

uniform sampler2D colortex0;

varying vec2 texcoord;

/* DRAWBUFFERS:2 */

void main() {
    vec3 scene = texture2D(colortex0, texcoord).rgb;

    float brightness = dot(scene, vec3(0.299, 0.587, 0.114));
    float threshold  = smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + 0.35, brightness);

    gl_FragData[0] = vec4(scene * threshold, 1.0);
}
