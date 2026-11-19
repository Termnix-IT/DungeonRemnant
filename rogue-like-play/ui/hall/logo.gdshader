// The game's logo on the opening (HubOpening): forged gold that a light
// writes out of the dark, crossing it from the left with the letters
// standing where it has passed (`shown`), with a light that crosses it
// again now and then (`sheen`: where the
// light is across the logo, off either end when there is none) and a slow
// ember in the metal. `fade` takes the whole away.
shader_type canvas_item;

uniform float shown = 1.0;
uniform float sheen = -1.0;
uniform float fade = 1.0;
uniform float clock = 0.0;
uniform vec4 light_colour : source_color = vec4(1.0, 0.92, 0.68, 1.0);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 px = texture(TEXTURE, UV);
	// A light crosses it from the left, leaning, and the letters stand
	// where it has passed: the name is written in reading order.
	float across = UV.x + (0.5 - UV.y) * 0.3;
	float front = mix(-0.3, 1.35, shown);
	float seen = smoothstep(front, front - 0.16, across);
	float lead = smoothstep(0.14, 0.0, abs(across - front)) * (1.0 - smoothstep(0.9, 1.0, shown));
	// A band of light crossing the letters now and then.
	float band = smoothstep(0.11, 0.0, abs(across - sheen));
	float ember = 0.94 + 0.06 * sin(clock * 1.1 + UV.x * 5.0);
	vec3 col = px.rgb * ember * (1.0 + 0.7 * lead) + light_colour.rgb * (band * 0.6 + lead * 0.6);
	COLOR = vec4(col, px.a * max(seen, lead * 0.5) * fade) * tint;
}
