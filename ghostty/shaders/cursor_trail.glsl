// Smooth fading trail when the cursor moves. Runs before bloom.glsl,
// so the cursor and trail get the same glow as the text.

const float DURATION = 0.2;      // trail lifetime, seconds
const float TRAIL_STRENGTH = 0.7;
const float TYPING_STRENGTH = 0.25; // fraction of the trail kept for one-cell moves (typing)

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

// iCurrentCursor.xy is the top-left corner (y points up), .zw the size.
vec2 cursorCenter(vec4 cursor) {
    return cursor.xy + vec2(0.5, -0.5) * cursor.zw;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 color = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = color;
    if (iFocus == 0 || iCursorVisible.x < 0.5) return;

    vec2 cur = cursorCenter(iCurrentCursor);
    vec2 prev = cursorCenter(iPreviousCursor);

    // The tail eases from the old position to the new one and fades.
    // Skipped for big jumps (clear screen, switching panes) so it doesn't streak.
    float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    float ease = 1.0 - pow(1.0 - t, 3.0);
    float fade = 1.0 - ease;
    float dist = distance(cur, prev);
    if (fade <= 0.0 || dist >= iResolution.y * 0.5) return;

    // Typing moves about half a cursor height per key: keep it light.
    // Ramp up to the full trail for moves of a few cells or more.
    float h = iCurrentCursor.w;
    fade *= mix(TYPING_STRENGTH, 1.0, smoothstep(h, h * 4.0, dist));

    vec2 tail = mix(prev, cur, ease);
    float thickness = iCurrentCursor.w * 0.35 * fade;
    float d = sdSegment(fragCoord, tail, cur) - thickness;
    float trail = (1.0 - smoothstep(0.0, 1.5, d)) * fade * TRAIL_STRENGTH;

    fragColor = vec4(mix(color.rgb, iCurrentCursorColor.rgb, trail), max(color.a, trail));
}
