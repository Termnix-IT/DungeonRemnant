// The fire in a brazier beside a gate (RouteGateView): a flame built of
// rising noise, white at its heart and the fire's colour at its tips, added
// over what is behind it. `power` is how high it burns (0: embers only).
shader_type canvas_item;
render_mode blend_add;

uniform vec4 colour : source_color = vec4(1.0, 0.58, 0.22, 1.0);
uniform float power = 1.0;
uniform float clock = 0.0;
// Sets this fire apart from the next.
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// From the bowl (0) up to the flame's tip (1), and across (-1 to 1).
	float up = 1.0 - UV.y;
	float across = (UV.x - 0.5) * 2.0;
	float rise = clock * 1.7 + seed;
	float high = mix(0.3, 1.0, clamp(power, 0.0, 1.2));
	// The flame sways as a whole, more the higher it is.
	across += (noise(vec2(up * 1.8 - rise * 0.9, seed)) - 0.5) * 0.7 * up;
	// Tongues of it climb and break away: noise drawn upward, eaten from
	// the sides and from above.
	float lick = noise(vec2(across * 2.3 + seed, up * 2.7 - rise * 1.5)) * 0.5 + noise(vec2(across * 4.8 - seed, up * 5.6 - rise * 2.5)) * 0.32 + noise(vec2(across * 9.5, up * 11.0 - rise * 3.8)) * 0.18;
	float lost = abs(across) * (1.25 + up * 2.2) + pow(up / high, 1.5) * 0.95;
	float flame = clamp((lick * 1.55 + 0.3 - lost) * 2.2, 0.0, 1.0);
	flame *= smoothstep(0.0, 0.06, up);
	// Embers glowing in the bowl whatever the flame does.
	float bed = exp(-pow(up / 0.06, 2.0)) * (1.0 - smoothstep(0.45, 0.85, abs((UV.x - 0.5) * 2.0))) * (0.5 + 0.5 * noise(vec2(UV.x * 14.0, rise * 0.6)));
	// White at its heart, the fire's colour in its body, a deep red at its edge.
	vec3 heat = mix(colour.rgb * vec3(0.9, 0.45, 0.35), colour.rgb, smoothstep(0.05, 0.45, flame));
	heat = mix(heat, vec3(1.0, 0.95, 0.8), smoothstep(0.55, 1.0, flame) * (1.0 - up / high * 0.6));
	vec3 col = heat * pow(flame, 1.3) * (0.55 + 0.6 * power) + colour.rgb * bed * 0.85;
	COLOR = vec4(col * COLOR.a, 1.0);
}
