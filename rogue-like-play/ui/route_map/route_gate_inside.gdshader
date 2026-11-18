// What is seen through a gate (RouteGateView): the place the gate leads to,
// in the light of what it gives. Drawn on the gate's light picture
// (gate_<chapter>_light.png), whose red is the opening; `opening` is where
// the opening lies in it (x, y, width, height of the UV), and `beyond` is
// the painting of the place (inside_<kind>.png: a road, an arena, a small
// chamber, the boss's nave), nearly colourless, bright only far in.
//
// It is a place and not a picture hung in the gate: it slides against the
// stone as the view leans (`shift`), more of it comes into sight as she
// nears (`deep`), its far light swells with the gate's strength, mist lies
// on its floor, and what stands on the threshold darkens the floor under it
// (`feet`).
shader_type canvas_item;

// Where the painting's far light lies (the point its lines run to).
const vec2 FAR = vec2(0.5, 0.48);

uniform sampler2D beyond : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 colour : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform vec4 dark : source_color = vec4(0.03, 0.028, 0.03, 1.0);
// 0: out; about 0.4: smouldering; 1: turned to; past 1: flaring.
uniform float power = 1.0;
uniform vec4 opening = vec4(0.2, 0.2, 0.6, 0.8);
uniform vec2 shift = vec2(0.0);
uniform float deep = 0.0;
// What stands on the threshold: its middle and half its width (shares of the
// opening's width), and how dark it makes the floor under it.
uniform vec3 feet = vec3(0.5, 0.3, 0.0);
uniform float clock = 0.0;
// She is walking into it: the far light comes to meet her.
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
	// The place beyond: the middle of its painting at rest, all of it as she
	// comes up to the threshold.
	float seen = mix(0.8, 1.0, deep);
	vec2 look = FAR + (q - FAR) * seen + shift;
	float value = dot(textureLod(beyond, clamp(look, vec2(0.003), vec2(0.997)), 0.8).rgb, vec3(0.3, 0.5, 0.2));
	float strength = power + flood * 0.55;
	vec3 tone = mix(colour.rgb, vec3(1.0), clamp(smoothstep(0.5, 1.1, value * strength) * 0.55 + flood * 0.12, 0.0, 1.0));
	vec3 col = dark.rgb + tone * value * (0.16 + 1.5 * strength);
	// Its far light, swelling with the gate's strength.
	vec2 far = (q - (FAR - shift / seen)) / vec2(0.46 + flood * 0.22, 0.34 + flood * 0.22);
	col += tone * exp(-dot(far, far) * 1.7) * strength * (0.5 + 0.06 * sin(clock * 1.3));
	// Light pooled on its threshold, rising in slow wisps.
	float low = clamp(q.y, 0.0, 1.0);
	float wisp = noise(vec2(q.x * 3.2, q.y * 2.4 + clock * 0.16)) * 0.6 + noise(vec2(q.x * 7.0 + 3.0, q.y * 5.0 + clock * 0.27)) * 0.4;
	col += tone * pow(low, 3.2) * (0.3 + 0.5 * wisp) * strength * 0.6;
	// Mist lying on its floor, drifting across.
	float lying = smoothstep(0.6, 0.98, q.y) * (0.35 + 0.65 * noise(vec2(q.x * 4.0 + clock * 0.11, q.y * 9.0 - clock * 0.03)));
	col += mix(tone, vec3(1.0), 0.25) * lying * (0.1 + 0.2 * strength);
	// The floor under what stands on the threshold.
	vec2 under = (q - vec2(feet.x, 0.992)) / vec2(max(feet.y, 0.01), 0.042);
	col *= 1.0 - exp(-dot(under, under)) * 0.8 * feet.z;
	COLOR = vec4(col, hole * COLOR.a);
}
