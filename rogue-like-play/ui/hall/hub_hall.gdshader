// The hub's hall (HubHall): the painting of the hall of preparation as a
// place and not a backdrop. A camera looks at it (`eye`, `zoom`: the opening
// draws back from the great gate, the departure goes into it); what is seen
// through the gate lies further off than the hall and slides less as the
// view leans (`lean`, `far_matte`: lobby_hall_far.png, bright where the far
// view is); haze drifts in it and its light swells and falls into the hall
// down the stairs; the hall's lamps flicker and warm the stone round them,
// and each can be out (`lamp_lit`), so the opening kindles them one by one
// out of the dark (`ambient`). The thing the lobby's chosen entry belongs to
// is lit (`focus`).
shader_type canvas_item;

const int LAMPS = 9;

uniform sampler2D painting : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D far_matte : filter_linear, repeat_disable;
// The share of the painting seen across and down at rest, and its width
// over its height.
uniform vec2 cover = vec2(1.0, 0.84);
uniform float aspect = 1.5;
uniform vec2 eye = vec2(0.5);
uniform float zoom = 1.0;
uniform vec2 lean = vec2(0.0);
uniform float clock = 0.0;
// Each lamp: where it hangs in the painting and how far its glow reaches (a
// share of the painting's height).
uniform vec3 lamps[LAMPS];
uniform float lamp_lit[LAMPS];
uniform vec4 lamp_colour : source_color = vec4(1.0, 0.68, 0.34, 1.0);
// The great gate: where its opening's middle is, where its light meets the
// hall's floor, its colour and how strongly it shines (1 at rest).
uniform vec2 gate = vec2(0.555, 0.27);
uniform vec2 gate_foot = vec2(0.552, 0.44);
uniform vec4 gate_colour : source_color = vec4(0.45, 0.62, 1.0, 1.0);
uniform float gate_power = 1.0;
uniform float gate_lit = 1.0;
// The lit thing: where, how far (a share of the height), its colour, how much.
uniform vec3 focus = vec3(0.5, 0.5, 0.1);
uniform vec4 focus_colour : source_color = vec4(1.0, 0.7, 0.38, 1.0);
uniform float focus_power = 0.0;
// 0: only what the lamps and the gate show; 1: the whole painting.
uniform float ambient = 1.0;
// The dark laid over the whole so the words on it read, and over its foot.
uniform float veil = 0.12;
uniform float foot = 0.0;

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
	vec2 p = eye + (UV - 0.5) * cover / zoom;
	// What is far slides less than what is near as the view leans.
	float deep = texture(far_matte, p).r;
	vec2 at = clamp(p + lean * mix(1.0, 0.25, deep), vec2(0.001), vec2(0.999));
	deep = texture(far_matte, at).r;
	vec3 col = texture(painting, at).rgb;
	float breath = 0.5 + 0.5 * sin(clock * 0.55);
	float shine = gate_power * gate_lit;

	// Through the gate: haze drifting across the far view, its light swelling.
	float haze = noise(vec2(at.x * 11.0 + clock * 0.045, at.y * 7.0 - clock * 0.02)) * 0.6 + noise(vec2(at.x * 25.0 - clock * 0.07, at.y * 16.0 + clock * 0.03)) * 0.4;
	vec3 beyond = col * (0.82 + 0.34 * shine * (0.65 + 0.35 * breath)) + gate_colour.rgb * (haze * 0.11 + 0.03) * shine;
	col = mix(col, beyond, deep);

	// Its light falling into the hall: a fan from the gate's foot down the
	// stairs and out over the floor, dust turning in it.
	vec2 fall = vec2((at.x - gate_foot.x) * aspect, at.y - gate_foot.y);
	float down = max(fall.y, 0.0);
	float wide = 0.07 + down * 0.55;
	float fan = smoothstep(wide, wide * 0.25, abs(fall.x)) * exp(-down * 3.4) * step(0.0, fall.y);
	float motes = 0.72 + 0.28 * noise(vec2(at.x * 30.0 + clock * 0.12, at.y * 18.0 - clock * 0.2));
	col += gate_colour.rgb * fan * motes * (0.035 + 0.05 * breath) * shine;
	col *= 1.0 + fan * 0.22 * (shine - 1.0);
	// A glow round the opening itself as it shines harder.
	vec2 round_gate = vec2((at.x - gate.x) * aspect, (at.y - gate.y) * 0.62);
	col += gate_colour.rgb * exp(-dot(round_gate, round_gate) * 34.0) * 0.16 * max(shine - 1.0, 0.0);

	// The lamps: a flickering glow, and the stone round each warmed by it.
	float warm = 0.0;
	float shown = 0.0;
	for (int i = 0; i < LAMPS; i++) {
		vec2 off = vec2((at.x - lamps[i].x) * aspect, at.y - lamps[i].y);
		float r2 = dot(off, off) / (lamps[i].z * lamps[i].z);
		float seed = float(i) * 17.3;
		float flick = 0.84 + 0.2 * noise(vec2(clock * 2.6 + seed, seed)) + 0.07 * sin(clock * 9.0 + seed);
		warm += exp(-r2 * 1.5) * lamp_lit[i] * flick;
		shown += exp(-r2 * 0.085) * lamp_lit[i];
	}
	col *= 1.0 + warm * 0.3;
	col += lamp_colour.rgb * warm * 0.17;

	// The thing the chosen entry belongs to.
	vec2 lit = vec2((at.x - focus.x) * aspect, at.y - focus.y);
	float held = exp(-dot(lit, lit) / (focus.z * focus.z) * 1.3) * focus_power * (0.86 + 0.14 * sin(clock * 2.2));
	col *= 1.0 + held * 0.75;
	col += focus_colour.rgb * held * 0.3;

	// Out of the dark: before the hall is whole, only what its lights show.
	float pool = exp(-dot(round_gate, round_gate) * 5.5) * 1.3;
	float seen = clamp(max(ambient, shown * 0.85 + (pool + fan * 2.2) * gate_lit), 0.0, 1.0);
	col *= mix(0.012, 1.0, seen * seen * (3.0 - 2.0 * seen));

	// The dark the words stand on, and the frame's own.
	col *= 1.0 - veil;
	col *= 1.0 - foot * smoothstep(0.52, 1.0, UV.y) * 0.62;
	vec2 rim = (UV - 0.5) * vec2(1.0, 0.82);
	col *= 1.0 - 0.42 * smoothstep(0.34, 0.86, length(rim));
	COLOR = vec4(col, 1.0);
}
