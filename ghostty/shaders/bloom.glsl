// Soft glow around bright text, the cursor and its trail.

const float THRESHOLD = 0.35; // luminance where text starts to glow
const float INTENSITY = 0.6;  // glow strength
const float SPREAD = 2.5;     // px between sample rings

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 color = texture(iChannel0, uv);

    // Sample 3 rings of 8 points, weighted toward the center.
    vec3 glow = vec3(0.0);
    float total = 0.0;
    for (int ring = 1; ring <= 3; ring++) {
        float weight = exp(-0.35 * float(ring * ring));
        for (int i = 0; i < 8; i++) {
            float angle = float(i) * 0.785398 + float(ring) * 0.392699;
            vec2 offset = vec2(cos(angle), sin(angle)) * float(ring) * SPREAD / iResolution.xy;
            vec3 s = texture(iChannel0, uv + offset).rgb;
            glow += s * smoothstep(THRESHOLD, THRESHOLD + 0.3, luma(s)) * weight;
            total += weight;
        }
    }

    fragColor = vec4(color.rgb + glow / total * INTENSITY, color.a);
}
