// The hall the route's gates stand in (RouteGates), over the whole screen:
// the chapter's painting far off in the dark above, and under the gates a
// paved floor laid in perspective. A causeway of worn slabs runs from each
// gate to the round stone she stands on, where the road she came by forks;
// down the middle of each runs a bronze channel that the gate's light flows
// along. The floor shows only where light falls on it: each gate throws its
// light out of its opening, spreading and thinning as it comes, with the
// shadow of what stands in the gate lying long down it; the trial's and the
// boss's fires light the stone beside their gates. Mist lies along the far
// wall, she casts a shadow away from the gate turned to, and the boss's toll
// flushes it all red.
//
// Everything is placed in the page's design space (1600x900) as the camera
// sees it: `origin` and `zoom` put that space in the rect, whose size in
// pixels is `extent`. The painting, being far, follows the camera less
// (`far_focus`, `far_zoom`).
shader_type canvas_item;

const int GATES = 3;
// A causeway's half width, the round stone's radius and one repeat of the
// hall's paving, in the floor's own units (the screen's width at a depth
// where one unit is `reach` px).
const float ROAD_HALF = 0.118;
const float DAIS = 0.105;
const float PAVING = 1.5;

uniform vec2 extent = vec2(1600.0, 900.0);
uniform vec2 origin = vec2(0.0);
uniform float zoom = 1.0;
// The point on the screen the far painting swells about, and by how much.
uniform vec2 far_focus = vec2(800.0, 450.0);
uniform float far_zoom = 1.0;
uniform sampler2D painting : source_color, filter_linear_mipmap, repeat_disable;
// The chapter's own ground (its colour and grit), the hall's flagstones, a
// causeway's slabs (across: its width; down: along it) and the round stone.
uniform sampler2D ground : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D flags : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dais : source_color, filter_linear_mipmap, repeat_disable;
// What stands in each gate, for the shadow it throws down the floor.
uniform sampler2D shade_0 : filter_linear_mipmap, repeat_disable;
uniform sampler2D shade_1 : filter_linear_mipmap, repeat_disable;
uniform sampler2D shade_2 : filter_linear_mipmap, repeat_disable;
// The painting's size, and how far it has slid sideways (px of the design space).
uniform vec2 painting_size = vec2(1672.0, 941.0);
uniform float drift = 0.0;
// The line the gates stand on, and where the floor runs out into the far dark.
uniform float floor_line = 516.0;
uniform float far_line = 452.0;
// The floor's perspective: the line its edges run to (far above the screen,
// as it is seen from above) and the eye's distance.
uniform float vanish = -320.0;
uniform float depth = 1930.0;
uniform vec4 night : source_color = vec4(0.02, 0.018, 0.02, 1.0);
uniform vec4 art : source_color = vec4(0.23, 0.23, 0.23, 1.0);
uniform int gate_count = 3;
uniform float gate_x[3];
uniform float gate_half[3];
uniform float gate_power[3];
uniform vec4 gate_colour[3] : source_color;
// Each gate's causeway: how brightly its channel runs with light, and how
// far down it the light has come (0: at the gate, 1: at her feet).
uniform float road_power[3];
uniform float road_fill[3];
// Her choice, sent up the channel of the gate chosen: which gate (x) and
// how far from her feet it has run (y: 0 to 1; under 0: none).
uniform vec2 spur = vec2(0.0, -1.0);
// What stands in each gate: its width and height on the page (0: nothing).
uniform vec2 shade_size[3];
// Each gate's fires: their strength (0: none), how far from its middle they
// stand, and their colour.
uniform float fire_power[3];
uniform float fire_off[3];
uniform vec4 fire_colour[3] : source_color;
// The round stone she stands on: the light in its grooves, and the gold of
// the road she came by.
uniform vec4 dais_colour : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float dais_power = 0.3;
uniform vec4 walked : source_color = vec4(0.86, 0.68, 0.36, 1.0);
// Where she stands (the round stone lies at `stand`), and how much of a
// shadow she casts.
uniform vec2 stand = vec2(800.0, 872.0);
uniform vec2 hero = vec2(800.0, 872.0);
uniform float hero_shadow = 1.0;
// The gate her shadow falls away from.
uniform float lamp_x = 800.0;
// The words under the gate turned to: the floor's light is hushed there.
uniform vec4 hush = vec4(0.0);
uniform float hush_share = 0.0;
uniform vec4 flush : source_color = vec4(0.74, 0.18, 0.14, 0.0);
// The hall going dark as she goes through the gate (0 to 1).
uniform float dusk = 0.0;
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

// A place of the page on the floor: across, and away (larger: farther).
vec2 on_floor(vec2 q) {
	float reach = max(q.y - vanish, 1.0);
	return vec2((q.x - 800.0) / reach, depth / reach);
}

// Where `w` lies on the road from `a` to `b`: across it, along it, its length.
vec3 on_road(vec2 w, vec2 a, vec2 b) {
	vec2 run = b - a;
	float len = max(length(run), 0.0001);
	vec2 way = run / len;
	return vec3(dot(w - a, vec2(-way.y, way.x)), dot(w - a, way), len);
}

float shape_of(sampler2D shape, vec2 uv, float soft) {
	return textureLod(shape, uv, soft).a;
}

void fragment() {
	vec2 at = UV * extent;
	vec2 p = (at - origin) / zoom;
	vec3 col = night.rgb;

	// The chapter's painting, far off: laid to cover the screen down to the
	// gates' line, soft, and falling into the dark toward its foot and sides.
	vec2 far_at = far_focus + (at - far_focus) / far_zoom;
	vec2 base_origin = (extent - vec2(1600.0, 900.0) * min(extent.x / 1600.0, extent.y / 900.0)) * 0.5;
	float base_zoom = min(extent.x / 1600.0, extent.y / 900.0);
	float line = base_origin.y + (floor_line + 72.0) * base_zoom;
	vec2 room = vec2(extent.x, max(line, 1.0));
	float fit = max(room.x / painting_size.x, room.y / painting_size.y);
	vec2 part = room / fit;
	vec2 uv = ((painting_size - part) * vec2(0.5, 0.25) + (far_at + vec2(drift * base_zoom, 0.0)) / fit) / painting_size;
	vec3 far = textureLod(painting, uv, 1.6).rgb * art.rgb;
	float down = clamp(far_at.y / room.y, 0.0, 1.0);
	float veil = down < 0.25 ? mix(0.9, 0.26, down / 0.25) : (down < 0.75 ? mix(0.26, 0.56, (down - 0.25) / 0.5) : mix(0.56, 1.0, (down - 0.75) / 0.25));
	float side = abs(far_at.x / extent.x - 0.5) * 2.0;
	veil = max(veil, smoothstep(0.62, 1.0, side) * 0.9);
	col = mix(far, night.rgb, veil);

	// The floor's own place under this pixel.
	vec2 w = on_floor(p);
	float reach = p.y - vanish;
	float gate_reach = floor_line - vanish;
	vec2 foot = on_floor(stand);

	// What each gate lights: its light thrown out of its opening, spreading
	// and thinning toward her, less where the one standing in it shades it.
	vec3 glow = vec3(0.0);
	vec3 haze = vec3(0.0);
	vec3 emit = vec3(0.0);
	float occluded = 0.0;
	for (int index = 0; index < GATES; index++) {
		if (index >= gate_count) {
			break;
		}
		float power = gate_power[index];
		vec3 tone = gate_colour[index].rgb;
		float x = gate_x[index];
		vec2 gate = on_floor(vec2(x, floor_line));
		float toward = gate.y - w.y;
		float across = w.x - gate.x;
		float open_half = gate_half[index] / gate_reach;
		float before = max(toward, 0.0);
		float wide = open_half * 0.94 + before * 0.52;
		float soft = 0.01 + before * 0.34;
		float fan = (1.0 - smoothstep(wide - soft, wide + soft, abs(across))) * smoothstep(-0.004, 0.014, toward);
		fan /= 1.0 + pow(before / 0.21, 2.0);
		// The pool at its threshold, wide and shallow.
		vec2 from = (p - vec2(x, floor_line + 6.0)) / vec2(gate_half[index] * 2.2, 70.0);
		float pool = exp(-dot(from, from) * 1.7);
		// The shadow of what stands in it, lying long down the light.
		float shadow = 0.0;
		vec2 figure = shade_size[index] / gate_reach;
		if (figure.x > 0.0 && toward > 0.0) {
			float lying = figure.y * 1.15;
			vec2 cast = vec2(across / (figure.x * (1.0 + before * 1.5)) + 0.5, 1.0 - before / lying);
			if (cast.x > 0.0 && cast.x < 1.0 && cast.y > 0.0) {
				float blur = 2.2 + before * 30.0;
				float shape = index == 0 ? shape_of(shade_0, cast, blur) : (index == 1 ? shape_of(shade_1, cast, blur) : shape_of(shade_2, cast, blur));
				shadow = shape * (1.0 - smoothstep(0.45, 1.0, before / lying)) * 0.82;
			}
		}
		glow += tone * power * (pool * 0.5 + fan * 1.25) * (1.0 - shadow);
		// The dust hanging in the light, in slow streaks.
		float streak = fbm(vec2(across * 9.0, before * 5.0 - clock * 0.05 + float(index) * 7.0));
		haze += tone * power * fan * (0.035 + 0.07 * streak) * (1.0 - shadow * 0.6);
		// And the air round the gate itself.
		vec2 about = (p - vec2(x, floor_line - 150.0)) / vec2(330.0, 300.0);
		haze += tone * power * exp(-dot(about, about) * 2.2) * 0.07;
		// Its fires: a pool of their light at either side, flickering.
		if (fire_power[index] > 0.0) {
			for (int hand = 0; hand < 2; hand++) {
				float fx = x + (hand == 0 ? -1.0 : 1.0) * fire_off[index];
				float flicker = 0.8 + 0.2 * noise(vec2(clock * 7.0 + float(index * 2 + hand) * 31.0, 0.0));
				vec2 lit = (p - vec2(fx, floor_line + 18.0)) / vec2(128.0, 50.0);
				glow += fire_colour[index].rgb * fire_power[index] * flicker * exp(-dot(lit, lit) * 1.25) * 0.75;
				vec2 air = (p - vec2(fx, floor_line - 96.0)) / vec2(120.0, 150.0);
				haze += fire_colour[index].rgb * fire_power[index] * flicker * exp(-dot(air, air) * 2.0) * 0.06;
				// And the dark under each fire's stand.
				vec2 under = (p - vec2(fx, floor_line + 4.0)) / vec2(30.0, 8.0);
				occluded = max(occluded, exp(-dot(under, under) * 1.3) * 0.8);
			}
		}
		// The dark where its jambs meet the floor.
		float jamb = abs(abs(p.x - x) - gate_half[index] * 1.23) / (gate_half[index] * 0.36);
		float low = (p.y - floor_line - 2.0) / 11.0;
		occluded = max(occluded, exp(-jamb * jamb - low * low) * 0.85);
	}

	// The floor: paving in perspective, seen only by that light.
	if (p.y > far_line && reach > 1.0) {
		// The hall's flagstones, in the chapter's own colour and grit.
		vec3 tone = textureLod(ground, vec2(0.5), 12.0).rgb;
		tone /= max(dot(tone, vec3(0.3, 0.5, 0.2)), 0.05);
		vec3 grit = texture(ground, w * 1.7).rgb / max(dot(textureLod(ground, vec2(0.5), 12.0).rgb, vec3(0.3, 0.5, 0.2)), 0.05);
		vec3 flag = texture(flags, w / PAVING).rgb;
		vec3 rock = flag * mix(tone, grit, 0.42) * 0.86;
		float gloss = dot(flag, vec3(0.3, 0.5, 0.2));

		// The causeways: the nearest of the roads this place lies on.
		float best = 10.0;
		vec3 best_at = vec3(0.0);
		int which = -1;
		for (int index = 0; index < GATES; index++) {
			if (index >= gate_count) {
				break;
			}
			vec3 lies = on_road(w, on_floor(vec2(gate_x[index], floor_line)), foot);
			if (lies.y > -0.03 && lies.y < lies.z && abs(lies.x) < best) {
				best = abs(lies.x);
				best_at = lies;
				which = index;
			}
		}
		// The road she came by, running on out of sight behind her.
		vec3 came = on_road(w, foot, on_floor(vec2(stand.x, stand.y + 700.0)));
		if (came.y > 0.0 && abs(came.x) < best) {
			best = abs(came.x);
			best_at = came;
			which = GATES;
		}
		float edge = fwidth(best_at.x) * 1.5 + 0.0015;
		float paved = which < 0 ? 0.0 : 1.0 - smoothstep(ROAD_HALF - edge, ROAD_HALF, best);
		if (paved > 0.0) {
			vec2 slab_uv = vec2(best_at.x / ROAD_HALF * 0.5 + 0.5, best_at.y / (ROAD_HALF * 6.0));
			vec3 slab = texture(road, slab_uv).rgb;
			rock = mix(rock, slab * mix(tone, vec3(1.0), 0.35) * 1.08, paved);
			gloss = mix(gloss, dot(slab, vec3(0.3, 0.5, 0.2)), paved);
			// The channel down its middle, running with the gate's light.
			float off = abs(slab_uv.x - 0.5);
			float core = 1.0 - smoothstep(0.008, 0.024, off);
			float halo = exp(-pow(off / 0.085, 2.0));
			vec3 shine = walked.rgb * 0.34;
			float shown = 1.0;
			float head = 0.0;
			float along = best_at.y / best_at.z;
			if (which < GATES) {
				shine = gate_colour[which].rgb * road_power[which];
				float filled = road_fill[which];
				shown = 1.0 - smoothstep(filled - 0.02, filled + 0.02, along);
				head = exp(-pow((along - filled) / 0.05, 2.0)) * step(filled, 0.985) * step(0.015, filled);
				if (spur.y >= 0.0 && which == int(spur.x + 0.5)) {
					head += exp(-pow((along - (1.0 - spur.y)) / 0.07, 2.0)) * 2.2 * (1.0 - spur.y * 0.4);
				}
			}
			float pulse = 0.72 + 0.28 * sin((best_at.y * 46.0 - clock * 3.4));
			emit += shine * paved * ((core * 0.8 + halo * 0.2) * shown * pulse + head * (core * 1.6 + halo * 0.8));
		}
		// The seam where a causeway is set into the hall's floor.
		rock *= 1.0 - 0.4 * (which < 0 ? 0.0 : exp(-pow((best - ROAD_HALF) / 0.006, 2.0)));

		// The round stone the roads meet at.
		vec2 round_at = (w - foot) / DAIS;
		float round_edge = fwidth(length(round_at)) * 1.5;
		float on_dais = 1.0 - smoothstep(1.0 - round_edge, 1.0, length(round_at));
		if (on_dais > 0.0) {
			vec4 disc = texture(dais, vec2(round_at.x, -round_at.y) * 0.5 + 0.5);
			float there = on_dais * disc.a;
			rock = mix(rock, disc.rgb * mix(tone, vec3(1.0), 0.35) * 1.1, there);
			float carved = smoothstep(0.36, 0.16, dot(disc.rgb, vec3(0.3, 0.5, 0.2)));
			emit *= 1.0 - there;
			emit += dais_colour.rgb * dais_power * carved * there * (0.85 + 0.15 * sin(clock * 2.1));
		}
		rock *= 1.0 - 0.45 * exp(-pow((length(round_at) - 1.04) / 0.05, 2.0));

		float near = smoothstep(far_line, far_line + 120.0, p.y);
		vec3 ground_lit = rock * (vec3(0.075, 0.075, 0.09) + glow * 1.5);
		// A sheen where the light runs along the stone.
		ground_lit += glow * gloss * gloss * 0.3;
		// Her shadow: a blot under her feet, and a long one thrown away from the gate.
		vec2 under = (p - hero - vec2(0.0, 2.0)) / vec2(46.0, 13.0);
		float blot = exp(-dot(under, under) * 1.4);
		vec2 away = normalize(hero - vec2(lamp_x, floor_line));
		vec2 rel = p - hero;
		float along_shadow = dot(rel, away);
		float off_shadow = abs(dot(rel, vec2(-away.y, away.x)));
		float cast = smoothstep(-4.0, 10.0, along_shadow) * (1.0 - smoothstep(30.0, 150.0, along_shadow)) * (1.0 - smoothstep(10.0, 26.0 + along_shadow * 0.12, off_shadow));
		ground_lit *= 1.0 - clamp(blot * 0.75 + cast * 0.5, 0.0, 0.85) * hero_shadow;
		ground_lit *= 1.0 - occluded;
		emit *= near;
		col = mix(col, ground_lit, near);
	}

	// The words' ground: the light hushed, soft at its edges.
	if (hush_share > 0.0) {
		vec2 inside = smoothstep(hush.xy - vec2(46.0, 18.0), hush.xy + vec2(34.0, 10.0), p) * (1.0 - smoothstep(hush.xy + hush.zw - vec2(34.0, 10.0), hush.xy + hush.zw + vec2(46.0, 26.0), p));
		float quiet = inside.x * inside.y * hush_share;
		col = mix(col, col * 0.2 + night.rgb * 0.5, quiet * 0.62);
		haze *= 1.0 - quiet * 0.8;
		emit *= 1.0 - quiet * 0.86;
	}
	col += emit;

	// Mist along the far wall, drifting, caught by the gates' light.
	float band = exp(-pow((p.y - far_line - 26.0) / 64.0, 2.0));
	float mist = fbm(vec2(p.x * 0.004 + clock * 0.012, p.y * 0.012 - clock * 0.004));
	col += (vec3(0.05, 0.055, 0.07) + glow * 0.5) * band * mist * 0.55;
	col += haze;

	// The dark at the screen's edges, the hall going dark as she leaves it,
	// and the boss's flush over it all.
	vec2 rim = (UV - 0.5) * vec2(1.0, 0.86);
	col *= 1.0 - smoothstep(0.42, 0.86, length(rim)) * 0.62;
	col = mix(col, night.rgb * 0.4, dusk);
	col = mix(col, flush.rgb, flush.a);
	COLOR = vec4(col, 1.0);
}
