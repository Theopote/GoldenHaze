/*
 * gbuffers_terrain — world geometry fragment shader
 * Writes lit scene color to colortex0, and a "bright-pass" extract
 * to colortex1 that composite/composite1 will blur into the bloom.
 */
#version 120

// Bloom bright-pass knee: values below the first number contribute
// nothing, values above the second contribute fully.
#define BLOOM_THRESHOLD 0.55 // [0.30 0.40 0.50 0.55 0.65 0.75 0.85]
#define SHIMMER_STRENGTH 1.0 // [0.00 0.30 0.60 1.00 1.50 2.00]

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 worldPos;
varying float blockId;

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
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.1) discard;

    vec3 light    = texture2D(lightmap, lmcoord).rgb;
    vec3 litColor = albedo.rgb * light;

    // Foliage shimmer (block.properties ID 1 = leaves): two layers of
    // fine noise scrolling over world-space position, thresholded
    // hard so only small bright flecks remain — sunlight catching
    // individual leaves as they sway. Scaled by sky light so it only
    // sparkles where the sun can actually reach, never in caves.
    float sparkle = 0.0;
    if (blockId > 0.5 && blockId < 1.5) {
        vec2 sp  = worldPos.xz * 2.5 + worldPos.yy * 1.7;
        float n1 = vnoise(sp * 3.0 + frameTimeCounter * vec2(0.9, 0.4));
        float n2 = vnoise(sp * 5.0 - frameTimeCounter * vec2(0.6, 0.8));
        float fleck = smoothstep(0.78, 0.95, n1 * n2 * 2.0);
        sparkle = fleck * lmcoord.y * SHIMMER_STRENGTH;
        litColor += vec3(1.00, 0.85, 0.55) * sparkle * 0.6;
    }

    gl_FragData[0] = vec4(litColor, albedo.a);

    // Bright-pass threshold — only strongly lit areas (sunlit leaves,
    // torches, sky glow near the sun) feed the bloom. Foliage flecks
    // get an extra push so they glitter through the bloom.
    float brightness = dot(litColor, vec3(0.299, 0.587, 0.114));
    float threshold  = smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + 0.35, brightness);
    gl_FragData[1] = vec4(litColor * threshold
                          + vec3(1.00, 0.85, 0.55) * sparkle * 0.5, 1.0);
}
