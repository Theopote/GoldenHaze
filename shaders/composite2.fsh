/*
 * composite2 — bloom blur pass 2 of 2 (vertical)
 * Finishes the separable Gaussian blur. colortex2 holds the final
 * bloom buffer read by final.fsh and sampled by composite3 god-rays.
 */
#version 120

uniform sampler2D colortex2;
uniform float viewHeight;

varying vec2 texcoord;

/* DRAWBUFFERS:2 */

void main() {
    float texel = 1.0 / viewHeight;

    float w[5];
    w[0] = 0.2270270270;
    w[1] = 0.1945945946;
    w[2] = 0.1216216216;
    w[3] = 0.0540540541;
    w[4] = 0.0162162162;

    vec3 result = texture2D(colortex2, texcoord).rgb * w[0];
    for (int i = 1; i < 5; i++) {
        float offset = texel * float(i) * 2.0;
        result += texture2D(colortex2, texcoord + vec2(0.0, offset)).rgb * w[i];
        result += texture2D(colortex2, texcoord - vec2(0.0, offset)).rgb * w[i];
    }

    gl_FragData[0] = vec4(result, 1.0);
}
