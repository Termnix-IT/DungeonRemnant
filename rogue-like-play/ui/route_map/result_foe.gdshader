shader_type canvas_item;

// Who felled her, standing over her sword in the dark (RunEndView): its
// bestiary picture held in the room's dusk, darker toward its head, with the
// embers' light on the edge of it turned to them and a faint wash of their
// red low on it, breathing as they do.

// What the dusk leaves of its colours.
uniform vec4 dusk : source_color = vec4(0.42, 0.38, 0.44, 1.0);
uniform vec4 ember : source_color = vec4(1.0, 0.44, 0.2, 1.0);
// The embers' breath (0 to 1), and how far the picture is in.
uniform float breath = 0.5;
uniform float shown = 1.0;
// Which way the embers lie from it, in the picture's own space (a picture
// drawn mirrored has its x turned).
uniform vec2 toward = vec2(1.0, 0.7);
// How far in from its edge their light reaches (pixels of the picture).
uniform float rim = 9.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float low = smoothstep(0.05, 1.0, UV.y);
	vec3 colour = base.rgb * dusk.rgb * mix(0.5, 1.0, low);
	// The edge turned to the embers: where the picture ends toward them.
	vec2 step_to = normalize(toward) * TEXTURE_PIXEL_SIZE * rim;
	float beyond = texture(TEXTURE, UV + step_to).a * 0.6 + texture(TEXTURE, UV + step_to * 0.5).a * 0.4;
	float edge = clamp(base.a - beyond, 0.0, 1.0);
	float glow = 0.75 + 0.25 * breath;
	colour += ember.rgb * edge * mix(0.35, 1.0, low) * glow;
	colour += ember.rgb * base.rgb * low * low * 0.3 * glow;
	COLOR = vec4(colour, base.a * shown) * COLOR;
}
