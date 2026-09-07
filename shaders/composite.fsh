/*
 * composite — bloom blur pass 1 of 2 (horizontal)
 * Reads the bright-pass buffer written in gbuffers_terrain and blurs
 * it horizontally with a 9-tap separable Gaussian. composite1.fsh
 * does the vertical half of the same blur.
 */
#version 120

uniform sampler2D colortex1;
uniform float viewWidth;

varying vec2 texcoord;

/* DRAWBUFFERS:1 */

void main() {
    float texel = 1.0 / viewWidth;

    float w[5];
    w[0] = 0.2270270270;
    w[1] = 0.1945945946;
    w[2] = 0.1216216216;
    w[3] = 0.0540540541;
    w[4] = 0.0162162162;

    vec3 result = texture2D(colortex1, texcoord).rgb * w[0];
    for (int i = 1; i < 5; i++) {
        float offset = texel * float(i) * 2.0;
        result += texture2D(colortex1, texcoord + vec2(offset, 0.0)).rgb * w[i];
        result += texture2D(colortex1, texcoord - vec2(offset, 0.0)).rgb * w[i];
    }

    gl_FragData[0] = vec4(result, 1.0);
}
