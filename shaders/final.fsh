/*
 * final — combine + warm color grade
 *
 * 1. Adds the blurred bloom (colortex1) back onto the scene (colortex0).
 * 2. Split-tones the image: shadows nudged cool/violet, highlights
 *    nudged warm/gold — the classic hand-painted-animation trick that
 *    makes flat lighting read as "warm sunlight" instead of just bright.
 * 3. Soft vignette + light grain to fake a painted-canvas feel.
 *
 * TODO for you / Cursor:
 *   - Custom sky gradient (multi-stop, painterly clouds) — skybasic
 *     now has a basic gradient; clouds are still missing.
 *   - Foliage/water shimmer — a subtle moving specular highlight tied
 *     to `frameTimeCounter`, sampled in gbuffers_terrain/water.
 */
#version 120

#define BLOOM_STRENGTH     0.8  // [0.00 0.20 0.40 0.60 0.80 1.00 1.30 1.60]
#define GODRAY_STRENGTH    0.9  // [0.00 0.30 0.60 0.90 1.20 1.60 2.00]
#define WARMTH             1.0  // [0.00 0.30 0.60 1.00 1.40 1.80]
#define VIGNETTE_STRENGTH  0.6  // [0.00 0.20 0.40 0.60 0.80 1.00]

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2; // god-ray accumulation (composite2)
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

void main() {
    vec3 scene  = texture2D(colortex0, texcoord).rgb;
    vec3 bloom  = texture2D(colortex1, texcoord).rgb;
    vec3 shafts = texture2D(colortex2, texcoord).rgb;

    vec3 color = scene + bloom * BLOOM_STRENGTH + shafts * GODRAY_STRENGTH;
    color = tonemap(color);
    color = warmGrade(color);

    vec2 uv = texcoord - 0.5;
    float vignette = 1.0 - dot(uv, uv) * VIGNETTE_STRENGTH;
    color *= vignette;

    float grain = fract(sin(dot(texcoord * vec2(viewWidth, viewHeight), vec2(12.9898, 78.233))) * 43758.5453);
    color += (grain - 0.5) * 0.015;

    gl_FragColor = vec4(color, 1.0);
}
