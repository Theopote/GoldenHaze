/*
 * final — combine + warm color grade
 *
 * 1. Adds the blurred bloom (colortex1) back onto the scene (colortex0).
 * 2. Split-tones the image: shadows nudged cool/violet, highlights
 *    nudged warm/gold — the classic hand-painted-animation trick that
 *    makes flat lighting read as "warm sunlight" instead of just bright.
 * 3. Soft vignette + fixed screen-space paper grain (very subtle).
 */
#version 120

#define BLOOM_STRENGTH     0.8  // [0.00 0.20 0.40 0.60 0.80 1.00 1.30 1.60]
#define GODRAY_STRENGTH    0.45 // [0.00 0.30 0.45 0.60 0.90 1.20 1.60 2.00]
#define WARMTH             1.0  // [0.00 0.30 0.60 1.00 1.40 1.80]
#define VIGNETTE_STRENGTH  0.6  // [0.00 0.20 0.40 0.60 0.80 1.00]
#define GRAIN_STRENGTH     0.35 // [0.00 0.30 0.35 0.60 1.00 1.50]
#define CHROMA_STRENGTH    0.0  // [0.00 0.30 0.60 1.00 1.50] optional cinematic

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2; // god-ray accumulation (composite2)
uniform sampler2D canvas;    // custom paper grain, bound via
                             // texture.canvas in shaders.properties
uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

vec3 warmGrade(vec3 color) {
    vec3 shadowTint    = vec3(0.05, 0.03, 0.08) * WARMTH;
    vec3 highlightTint = vec3(0.12, 0.07, -0.02) * WARMTH;

    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color += mix(shadowTint, highlightTint, smoothstep(0.2, 0.8, luma));

    // gentle saturation/contrast lift around mid-gray
    color = mix(vec3(luma), color, 1.0 + 0.15 * WARMTH);
    return color;
}

// filmic-ish shoulder so bloom + shafts roll off softly instead of
// clipping to dead white around the sun (tonemap before grading)
vec3 tonemap(vec3 x) {
    return x / (x + vec3(0.6));
}

// lifted blacks: shadows never reach 0, they settle into a soft
// dark-with-air look (hand-painted cels keep shadow detail readable).
// Also gently compresses the very top so highlights stay creamy.
vec3 softCurve(vec3 x) {
    return x * (0.92 + 0.08 * x) + vec3(0.028);
}

void main() {
    // optional chromatic aberration (default off): radial RGB offset
    // reads as lens dispersion, not hand-painted — keep at 0 unless
    // you want a deliberate cinematic look
    vec2 fromCenter = texcoord - 0.5;
    vec2 caOffset = fromCenter * (CHROMA_STRENGTH * 0.0015)
                  * dot(fromCenter, fromCenter) * 4.0;
    vec3 scene;
    scene.r = texture2D(colortex0, texcoord + caOffset).r;
    scene.g = texture2D(colortex0, texcoord).g;
    scene.b = texture2D(colortex0, texcoord - caOffset).b;

    vec3 bloom  = texture2D(colortex1, texcoord).rgb;
    vec3 shafts = texture2D(colortex2, texcoord).rgb;

    vec3 color = scene + bloom * BLOOM_STRENGTH + shafts * GODRAY_STRENGTH;
    color = tonemap(color);
    color = softCurve(color);
    color = warmGrade(color);

    vec2 uv = texcoord - 0.5;
    float vignette = 1.0 - dot(uv, uv) * VIGNETTE_STRENGTH;
    color *= vignette;

    // paper grain: fixed screen-space canvas texture, two octaves.
    // Does not scroll — drifting grain reads as film noise, not paper.
    vec2 res = vec2(viewWidth, viewHeight);
    float g1 = texture2D(canvas, texcoord * res / 256.0).r;
    float g2 = texture2D(canvas, texcoord * res / 512.0).r;
    float grain = (g1 * 0.65 + g2 * 0.35) - 0.5;
    // stronger in midtones/shadows, barely visible in highlights —
    // like pigment sitting in the tooth of the paper
    float luma2 = dot(color, vec3(0.299, 0.587, 0.114));
    color += grain * 0.05 * GRAIN_STRENGTH * (1.0 - luma2 * 0.6);

    gl_FragColor = vec4(color, 1.0);
}
