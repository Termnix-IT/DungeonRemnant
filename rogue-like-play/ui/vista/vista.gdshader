// The departure's vista (HubSortie): the chosen chapter's painting over the
// whole screen, as a place and not a picture. Its fires flicker and warm
// what stands round them (`fires`), the light at its way in swells and
// falls (`way`: the gate, stair or door each painting is drawn round), and
// mist drifts through it. Turning to another chapter is a turn of the head:
// the place turned from slides off one way as the one turned to comes in
// from the other, mist running along the edge between them (`turn`,
// `side`). A sealed place is dark and still (`still`). Over it lie the dark
// falls the page's words stand on: from the foot up, from the left in and
// from the top down.
shader_type canvas_item;

const int FIRES = 6;

uniform sampler2D place : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D place_from : source_color, filter_linear_mipmap, repeat_disable;
// The part of each painting seen (x, y, width, height of its UV).
uniform vec4 window = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 window_from = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 tint_from : source_color = vec4(1.0);
// 0: the place turned from; 1: the place turned to. `side`: 1 when the
// place turned to lies to the right, -1 to the left.
uniform float turn = 1.0;
uniform float side = 1.0;
// Each fire: where it burns in the painting, and how far its light reaches
// (a share of the painting's height; 0: no fire).
uniform vec3 fires[FIRES];
uniform vec4 fire_colour : source_color = vec4(1.0, 0.68, 0.34, 1.0);
uniform vec2 way = vec2(0.8, 0.45);
uniform vec4 way_colour : source_color = vec4(1.0, 0.74, 0.4, 1.0);
uniform float way_reach = 0.16;
uniform vec4 mist_colour : source_color = vec4(0.7, 0.76, 0.82, 0.22);
// 1: sealed, nothing in it stirs.
uniform float still = 0.0;
uniform float aspect = 1.777;
uniform float clock = 0.0;
uniform vec4 shade : source_color = vec4(0.0, 0.0, 0.0, 1.0);

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
	// The turn: both places slide the way the head turns.
	float settled = turn * turn * (3.0 - 2.0 * turn);
	vec2 at = window.xy + (UV + vec2(side * (1.0 - settled) * 0.07, 0.0)) * window.zw;
	vec2 from = window_from.xy + (UV - vec2(side * settled * 0.07, 0.0)) * window_from.zw;
	at = clamp(at, vec2(0.001), vec2(0.999));
	from = clamp(from, vec2(0.001), vec2(0.999));
	vec3 col = texture(place, at).rgb * tint.rgb;
	float alive = 1.0 - still;

	// Its fires.
	float warm = 0.0;
	for (int i = 0; i < FIRES; i++) {
		if (fires[i].z <= 0.0) {
			continue;
		}
		vec2 off = vec2((at.x - fires[i].x) * aspect, at.y - fires[i].y);
		float seed = float(i) * 13.7;
		float flick = 0.8 + 0.26 * noise(vec2(clock * 3.0 + seed, seed)) + 0.08 * sin(clock * 11.0 + seed);
		warm += exp(-dot(off, off) / (fires[i].z * fires[i].z) * 1.6) * flick;
	}
	col *= 1.0 + warm * 0.34 * alive;
	col += fire_colour.rgb * warm * 0.13 * alive;

	// The light at its way in, swelling and falling.
	vec2 toward = vec2((at.x - way.x) * aspect, at.y - way.y);
	float lit = exp(-dot(toward, toward) / (way_reach * way_reach));
	float breath = 0.5 + 0.5 * sin(clock * 0.8);
	col *= 1.0 + lit * (0.1 + 0.3 * breath) * alive;
	col += way_colour.rgb * lit * (0.03 + 0.07 * breath) * alive;

	// Mist drifting through it, thickest in its middle distance.
	float drift = noise(vec2(at.x * 4.0 + clock * 0.035, at.y * 7.0)) * 0.6 + noise(vec2(at.x * 9.0 - clock * 0.06, at.y * 15.0 + clock * 0.02)) * 0.4;
	float band = smoothstep(0.25, 0.6, at.y) * (1.0 - smoothstep(0.72, 0.98, at.y));
	col = mix(col, mist_colour.rgb, smoothstep(0.42, 0.9, drift) * band * mist_colour.a * alive);

	// The place turned from, the edge between them running across with
	// mist along it.
	if (turn < 1.0) {
		vec3 old = texture(place_from, from).rgb * tint_from.rgb;
		float across = side > 0.0 ? 1.0 - UV.x : UV.x;
		float ragged = noise(vec2(UV.y * 5.0, clock * 0.7)) - 0.5;
		float come = smoothstep(across - 0.3, across + 0.3, turn * 1.6 - 0.3 + ragged * 0.22);
		col = mix(old, col, come);
		col = mix(col, mist_colour.rgb * 0.8, come * (1.0 - come) * 1.6);
	}

	// The dark the words stand on.
	col = mix(col, shade.rgb, smoothstep(0.4, 1.0, UV.y) * 0.95);
	col = mix(col, shade.rgb, clamp(1.0 - UV.x / 0.52, 0.0, 1.0) * 0.55);
	col = mix(col, shade.rgb, clamp(1.0 - UV.y / 0.2, 0.0, 1.0) * 0.72);
	// Its own alpha is the page's: it comes through the gate's light with the page.
	COLOR = vec4(col, COLOR.a);
}
