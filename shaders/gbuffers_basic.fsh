#version 120

uniform sampler2D lightmap;

varying vec2 lmcoord;
varying vec4 vertexColor;

/* DRAWBUFFERS:01 */

void main() {
    vec3 light    = texture2D(lightmap, lmcoord).rgb;
    vec3 litColor = vertexColor.rgb * light;

    gl_FragData[0] = vec4(litColor, vertexColor.a);

    float brightness = dot(litColor, vec3(0.299, 0.587, 0.114));
    float threshold  = smoothstep(0.55, 0.9, brightness);
    gl_FragData[1] = vec4(litColor * threshold, 1.0);
}
