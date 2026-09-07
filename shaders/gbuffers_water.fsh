#version 120

#define BLOOM_THRESHOLD 0.55 // [0.30 0.40 0.50 0.55 0.65 0.75 0.85]
#define SHIMMER_STRENGTH 1.0 // [0.00 0.30 0.60 1.00 1.50 2.00]

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 viewPos;

/* DRAWBUFFERS:01 */

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),               hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

void main() {
    vec4 albedo   = texture2D(texture, texcoord) * vertexColor;
    vec3 light    = texture2D(lightmap, lmcoord).rgb;
    vec3 litColor = albedo.rgb * light;

    // Water shimmer: two noise layers scrolling in opposite directions
    // to fake crossing ripples; hard-thresholded into small glints of
    // reflected sunlight. Scaled by sky light (lmcoord.y) so shaded or
    // underground water stays dull.
    vec2 wp  = viewPos.xz;
    float n1 = vnoise(wp * 1.6 + frameTimeCounter * vec2(0.35, 0.15));
    float n2 = vnoise(wp * 2.3 - frameTimeCounter * vec2(0.22, 0.40));
    float glint = smoothstep(0.72, 0.92, n1 * n2 * 2.0);
    float sparkle = glint * lmcoord.y * SHIMMER_STRENGTH;
    litColor += vec3(1.00, 0.88, 0.60) * sparkle * 0.8;

    gl_FragData[0] = vec4(litColor, albedo.a);

    float brightness = dot(litColor, vec3(0.299, 0.587, 0.114));
    float threshold  = smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + 0.35, brightness);
    // water glints punch harder into the bloom: sparkling ripples
    gl_FragData[1] = vec4(litColor * threshold
                          + vec3(1.00, 0.88, 0.60) * sparkle * 0.9, 1.0);
}
