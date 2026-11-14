// A hairline down the middle of the rect, `width` pixels wide, at full
// strength along its middle and fading to nothing over `fade` of its length
// at each end. `extent` is the rect's size in pixels, set by Ornament.
shader_type canvas_item;

instance uniform vec4 tint = vec4(1.0);
instance uniform vec2 extent = vec2(100.0);
instance uniform float width = 1.0;
instance uniform float fade = 0.1;

void fragment() {
	float x = abs((UV.x - 0.5) * extent.x);
	float aa = max(fwidth(x), 0.0001);
	float line = 1.0 - smoothstep(width * 0.5 - aa * 0.5, width * 0.5 + aa * 0.5, x);
	float ends = clamp(min(UV.y, 1.0 - UV.y) / max(fade, 0.0001), 0.0, 1.0);
	COLOR = vec4(tint.rgb, tint.a * line * ends);
}
