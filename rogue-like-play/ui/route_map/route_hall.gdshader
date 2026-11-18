// The hall the route's gates stand in (RouteGates), over the whole screen:
// the chapter's painting far off in the dark above, and under the gates the
// chapter's own stone floor laid in perspective, lit by what each gate
// throws down it. A gate's light is a pool at its threshold and a beam
// running down the floor to her feet; the stone shows only where light
// falls on it. Mist lies along the far wall and drifts in the beams, she
// casts a shadow away from the gate turned to, and the boss's toll flushes
// it all red.
//
// Everything is placed in the page's design space (1600x900): `origin` and
// `zoom` put that space in the rect, whose size in pixels is `extent`.
shader_type canvas_item;

const int GATES = 3;

uniform vec2 extent = vec2(1600.0, 900.0);
uniform vec2 origin = vec2(0.0);
uniform float zoom = 1.0;
uniform sampler2D painting : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D ground : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// The painting's size, and how far it has slid sideways (px of the design space).
uniform vec2 painting_size = vec2(1672.0, 941.0);
uniform float drift = 0.0;
// The line the gates stand on, and where the floor runs out into the far dark.
uniform float floor_line = 516.0;
uniform float far_line = 452.0;
// The floor's perspective: the line its edges run to (far above the screen,
// as it is seen from above), the eye's distance, and a stone's size.
uniform float vanish = -320.0;
uniform float depth = 1930.0;
uniform float stone = 0.062;
uniform vec4 night : source_color = vec4(0.02, 0.018, 0.02, 1.0);
uniform vec4 art : source_color = vec4(0.23, 0.23, 0.23, 1.0);
uniform int gate_count = 3;
uniform float gate_x[3];
uniform float gate_half[3];
uniform float gate_power[3];
uniform vec4 gate_colour[3] : source_color;
// Where she stands, and how much of a shadow she casts.
uniform vec2 hero = vec2(800.0, 858.0);
uniform float hero_shadow = 1.0;
// The gate her shadow falls away from.
uniform float lamp_x = 800.0;
// The words under the gate turned to: the floor's light is hushed there.
uniform vec4 hush = vec4(0.0);
uniform float hush_share = 0.0;
uniform vec4 flush : source_color = vec4(0.74, 0.18, 0.14, 0.0);
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

float fbm(vec2 p) {
	float sum = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		sum += noise(p) * weight;
		p = p * 2.03 + vec2(17.0, 9.0);
		weight *= 0.5;
	}
	return sum;
}

void fragment() {
	vec2 at = UV * extent;
	vec2 p = (at - origin) / zoom;
	vec3 col = night.rgb;

	// The chapter's painting, far off: laid to cover the screen down to the
	// gates' line, soft, and falling into the dark toward its foot and sides.
	float line = origin.y + (floor_line + 72.0) * zoom;
	vec2 room = vec2(extent.x, max(line, 1.0));
	float fit = max(room.x / painting_size.x, room.y / painting_size.y);
	vec2 part = room / fit;
	vec2 uv = ((painting_size - part) * vec2(0.5, 0.25) + (at + vec2(drift * zoom, 0.0)) / fit) / painting_size;
	vec3 far = textureLod(painting, uv, 1.6).rgb * art.rgb;
	float down = clamp(at.y / room.y, 0.0, 1.0);
	float veil = down < 0.25 ? mix(0.92, 0.35, down / 0.25) : (down < 0.75 ? mix(0.35, 0.62, (down - 0.25) / 0.5) : mix(0.62, 1.0, (down - 0.75) / 0.25));
	float side = abs(at.x / extent.x - 0.5) * 2.0;
	veil = max(veil, smoothstep(0.62, 1.0, side) * 0.9);
	col = mix(far, night.rgb, veil);

	// What each gate lights.
	vec3 glow = vec3(0.0);
	vec3 haze = vec3(0.0);
	for (int index = 0; index < GATES; index++) {
		if (index >= gate_count) {
			break;
		}
		float power = gate_power[index];
		vec3 tone = gate_colour[index].rgb;
		float x = gate_x[index];
		// The pool at its threshold, wide and shallow.
		vec2 from = (p - vec2(x, floor_line + 6.0)) / vec2(gate_half[index] * 2.3, 86.0);
		float pool = exp(-dot(from, from) * 1.6);
		// The beam down the floor to her feet, narrowing and thinning as it comes.
		float along = (p.y - floor_line) / max(hero.y - floor_line, 1.0);
		float middle = mix(x, hero.x, clamp(along, 0.0, 1.0));
		float half_wide = mix(gate_half[index] * 0.92, 40.0, clamp(along, 0.0, 1.0));
		float across = abs(p.x - middle) / half_wide;
		float beam = (1.0 - smoothstep(0.55, 1.0, across)) * smoothstep(-0.02, 0.05, along) * (1.0 - smoothstep(0.92, 1.18, along));
		beam *= mix(1.0, 0.24, clamp(along, 0.0, 1.0));
		glow += tone * power * (pool * 0.85 + beam * 0.62);
		// The dust hanging in the beam, in slow streaks.
		float streak = fbm(vec2((p.x - middle) * 0.02, along * 3.0 - clock * 0.05 + float(index) * 7.0));
		haze += tone * power * beam * (0.05 + 0.1 * streak);
		// And the air round the gate itself.
		vec2 about = (p - vec2(x, floor_line - 150.0)) / vec2(330.0, 300.0);
		haze += tone * power * exp(-dot(about, about) * 2.2) * 0.07;
	}

	// The floor: the chapter's stone in perspective, seen only by that light.
	float reach = p.y - vanish;
	if (p.y > far_line && reach > 1.0) {
		vec2 tile = vec2((p.x - 800.0) / reach, depth / reach) / stone;
		vec3 rock = texture(ground, tile * 0.25).rgb;
		float near = smoothstep(far_line, far_line + 120.0, p.y);
		vec3 ground_lit = rock * (vec3(0.085, 0.085, 0.1) + glow * 1.45);
		// A sheen where the light runs along the stone.
		float gloss = dot(rock, vec3(0.3, 0.5, 0.2));
		ground_lit += glow * gloss * gloss * 0.35;
		// Her shadow: a blot under her feet, and a long one thrown away from the gate.
		vec2 under = (p - hero - vec2(0.0, 2.0)) / vec2(46.0, 13.0);
		float blot = exp(-dot(under, under) * 1.4);
		vec2 away = normalize(hero - vec2(lamp_x, floor_line));
		vec2 rel = p - hero;
		float along_shadow = dot(rel, away);
		float off_shadow = abs(dot(rel, vec2(-away.y, away.x)));
		float cast = smoothstep(-4.0, 10.0, along_shadow) * (1.0 - smoothstep(30.0, 150.0, along_shadow)) * (1.0 - smoothstep(10.0, 26.0 + along_shadow * 0.12, off_shadow));
		ground_lit *= 1.0 - clamp(blot * 0.75 + cast * 0.5, 0.0, 0.85) * hero_shadow;
		col = mix(col, ground_lit, near);
	}

	// The words' ground: the light hushed, soft at its edges.
	if (hush_share > 0.0) {
		vec2 inside = smoothstep(hush.xy - vec2(46.0, 18.0), hush.xy + vec2(34.0, 10.0), p) * (1.0 - smoothstep(hush.xy + hush.zw - vec2(34.0, 10.0), hush.xy + hush.zw + vec2(46.0, 26.0), p));
		float quiet = inside.x * inside.y * hush_share;
		col = mix(col, col * 0.2 + night.rgb * 0.5, quiet * 0.86);
		haze *= 1.0 - quiet * 0.8;
	}

	// Mist along the far wall, drifting, caught by the gates' light.
	float band = exp(-pow((p.y - far_line - 26.0) / 64.0, 2.0));
	float mist = fbm(vec2(p.x * 0.004 + clock * 0.012, p.y * 0.012 - clock * 0.004));
	col += (vec3(0.05, 0.055, 0.07) + glow * 0.5) * band * mist * 0.55;
	col += haze;

	// The dark at the screen's edges, and the boss's flush over it all.
	vec2 edge = (UV - 0.5) * vec2(1.0, 0.86);
	col *= 1.0 - smoothstep(0.42, 0.86, length(edge)) * 0.62;
	col = mix(col, flush.rgb, flush.a);
	COLOR = vec4(col, 1.0);
}
