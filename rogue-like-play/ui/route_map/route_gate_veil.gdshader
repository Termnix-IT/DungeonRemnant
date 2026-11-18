// The light standing in a gate's opening (RouteGateView): a veil in the
// colour of what the gate gives, brightest at the threshold, rising in slow
// wisps and thin rays. Drawn on the gate's light picture
// (gate_<chapter>_light.png), whose red is the opening; `opening` is where
// the opening lies in it (x, y, width, height of the UV).
shader_type canvas_item;

uniform vec4 colour : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform vec4 dark : source_color = vec4(0.03, 0.028, 0.03, 1.0);
// 0: out; about 0.4: smouldering; 1: turned to; past 1: flaring.
uniform float power = 1.0;
uniform vec4 opening = vec4(0.2, 0.2, 0.6, 0.8);
uniform float clock = 0.0;
// She is walking into it: the light whitens and fills the opening.
uniform float flood = 0.0;

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
	float hole = texture(TEXTURE, UV).r;
	vec2 q = (UV - opening.xy) / opening.zw;
	float low = clamp(q.y, 0.0, 1.0);
	// The light pooled at the threshold, thinning toward the arch.
	float base = pow(low, 1.7);
	// Wisps rising, and thin rays standing in it.
	float wisp = noise(vec2(q.x * 3.2, q.y * 2.4 + clock * 0.16)) * 0.6 + noise(vec2(q.x * 7.0 + 3.0, q.y * 5.0 + clock * 0.27)) * 0.4;
	float ray = noise(vec2(q.x * 15.0, clock * 0.06));
	float glow = base * (0.72 + 0.5 * wisp) + 0.1 + ray * ray * 0.22 * (0.35 + low);
	// A heart of light low in the middle.
	vec2 heart = (q - vec2(0.5, 1.02)) / vec2(0.62, 0.5);
	glow += exp(-dot(heart, heart) * 2.4) * 0.5;
	float lit = clamp(glow * power, 0.0, 1.6);
	vec3 tone = mix(colour.rgb, vec3(1.0), clamp(0.3 * base * power + flood, 0.0, 1.0));
	vec3 col = mix(dark.rgb, tone, clamp(lit, 0.0, 1.0)) + tone * max(lit - 1.0, 0.0) * 0.5;
	col = mix(col, vec3(1.0), flood * 0.8);
	COLOR = vec4(col, hole * COLOR.a);
}
