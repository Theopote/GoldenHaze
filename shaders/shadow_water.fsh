#version 120

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 vertexColor;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if (albedo.a < 0.1) discard;

    gl_FragData[0] = vec4(1.0);
}
