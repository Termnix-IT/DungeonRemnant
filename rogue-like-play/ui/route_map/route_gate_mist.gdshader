// The mist on a gate's threshold (RouteGateView), drawn in front of what
// stands in the gate so that its feet are in it and not on it. Drawn on the
// gate's light picture, whose red is the opening; `opening` is where the
// opening lies in it (x, y, width, height of the UV).
shader_type canvas_item;

uniform vec4 colour : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float power = 1.0;
uniform vec4 opening = vec4(0.2, 0.2, 0.6, 0.8);
uniform float clock = 0.0;

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
	float low = smoothstep(0.74, 1.0, q.y);
	float drift = noise(vec2(q.x * 3.0 + clock * 0.09, q.y * 7.0)) * 0.6 + noise(vec2(q.x * 6.5 - clock * 0.13, q.y * 12.0 + 3.0)) * 0.4;
	float there = low * (0.2 + 0.8 * drift) * (0.3 + 0.45 * clamp(power, 0.0, 1.3));
	vec3 col = mix(colour.rgb, vec3(1.0), 0.35) * (0.45 + 0.55 * clamp(power, 0.0, 1.2));
	COLOR = vec4(col, there * hole * COLOR.a);
}
