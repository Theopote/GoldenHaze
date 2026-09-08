/*
 * composite2 — god rays (crepuscular / "Tindal" light shafts)
 *
 * Runs after the two bloom blur passes. Marches from each pixel
 * toward the sun's screen-space position, accumulating the blurred
 * bright-pass buffer (colortex1). Where leaves/geometry block the
 * sky, colortex1 is dark and the shaft dies out; through gaps in
 * the canopy colortex1 still carries the sky/sun glow, so light
 * visibly "leaks" through leaves as broken shafts — the approximate
 * occlusion comes for free from the bright-pass instead of a depth
 * compare, which is cheaper and looks softer (fits the painted look).
 *
 * Result is written to colortex2 so final.fsh can grade and weigh
 * shafts independently from the regular bloom.
 *
 * Toggle: ENABLE_GODRAYS (see shaders.properties).
 */
#version 120

// Toggle in the shader options GUI, or flip the default here.
#define ENABLE_GODRAYS // [on/off default: on]

#define GODRAY_SAMPLES   64    // [32 48 64 80 100]
#define GODRAY_DENSITY    0.85 // [0.50 0.65 0.85 1.00 1.20]
#define GODRAY_DECAY      0.94 // [0.88 0.91 0.94 0.96 0.98]
#define GODRAY_EXPOSURE   0.50 // [0.25 0.35 0.50 0.70 1.00]

// Derive from GODRAY_SAMPLES so brightness normalization stays correct
// when the in-game sample-count slider is changed.
#define GODRAY_SAMPLES_F  float(GODRAY_SAMPLES)

uniform sampler2D colortex1;
uniform vec3 sunPosition;            // view-space direction to sun
uniform mat4 gbufferProjection;
uniform float aspectRatio;
uniform float rainStrength;

varying vec2 texcoord;

/* DRAWBUFFERS:2 */

void main() {
    vec3 shafts = vec3(0.0);

#ifdef ENABLE_GODRAYS
    float sunUp = normalize(sunPosition).y;

    // skip entirely when the sun is below / hugging the horizon
    if (sunUp > -0.08) {
        vec3 sunDir = normalize(sunPosition);

        // sun behind the camera (view space forward is -Z): fade out
        // instead of trusting the projected screen position, which
        // mirrors to the opposite side when sunDir.z crosses zero
        float inFront = smoothstep(-0.05, 0.15, -sunDir.z);

        // project the sun direction to screen space
        vec4 clip = gbufferProjection * vec4(sunPosition, 1.0);
        vec2 sunScreen = clip.xy / clip.w * 0.5 + 0.5;

        // aspect-corrected distance from the sun, for edge fade
        vec2 dAspect = (texcoord - sunScreen) * vec2(aspectRatio, 1.0);
        float distFromSun = length(dAspect);

        // fade shafts when looking far from the sun; keep a wider
        // margin when the sun is off-screen so shafts still sweep in
        float vis = 1.0 - smoothstep(0.55, 1.55, distFromSun);
        vis *= inFront;

        if (vis > 0.001) {
            vec2 dir = (sunScreen - texcoord) * (GODRAY_DENSITY / GODRAY_SAMPLES_F);

            vec2 sampleUV = texcoord;
            float illum = 1.0;

            for (int i = 0; i < GODRAY_SAMPLES; i++) {
                sampleUV += dir;

                // sample point off-screen: contribute nothing instead
                // of pulling in a clamped edge pixel that causes streaks
                vec2 inBounds = step(vec2(0.0), sampleUV) * step(sampleUV, vec2(1.0));
                float boundsMask = inBounds.x * inBounds.y;

                vec3 s = texture2D(colortex1, sampleUV).rgb;
                shafts += s * illum * boundsMask;
                illum  *= GODRAY_DECAY;
            }

            shafts *= GODRAY_EXPOSURE / GODRAY_SAMPLES_F;

            // warm sunlight tint, stronger warmth at low sun angles
            float lowSun = 1.0 - smoothstep(0.0, 0.55, sunUp);
            vec3 tint = mix(vec3(1.00, 0.80, 0.50), vec3(1.00, 0.60, 0.30), lowSun);
            shafts *= tint;

            // day factor, horizon fade, rain kills shafts
            shafts *= smoothstep(-0.08, 0.06, sunUp);
            shafts *= 1.0 - rainStrength;
            shafts *= vis;
        }
    }
#endif

    gl_FragData[0] = vec4(shafts, 1.0);
}
