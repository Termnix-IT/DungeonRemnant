shader_type canvas_item;
render_mode blend_add, unshaded;

// What drifts in the air of a battlefield (AreaGround): dust settling in a
// ruin, spores and fireflies in the woods, embers rising off the ash, cold
// lights rising out of the deep. Small lights, few and faint, added over
// the fight; each keeps its place in a grid that drifts as a whole, so none
// ever appears or goes out of nothing. They are only seen, never touched.

// The sheet this is drawn on, in the world (as the floor's).
uniform vec2 sheet_from = vec2(0.0);
uniform vec2 sheet_size = vec2(1024.0);
// A mote's colour (alpha: how bright), which way and how fast they drift
// (world px a second), the share of the grid's cells that hold one, a
// mote's size (world px) and how much it flickers (0 to 1).
uniform vec4 mote : source_color = vec4(0.8, 0.85, 1.0, 0.3);
uniform vec2 drift = vec2(-6.0, 8.0);
uniform float share = 0.4;
uniform float across = 2.6;
uniform float flicker = 0.3;
uniform float clock = 0.0;

vec2 air_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// One grid of motes: `cell` world px across, drifting at `pace` of the drift.
float motes(vec2 at, float cell, float pace, float seed) {
	vec2 moved = (at - drift * clock * pace) / cell;
	vec2 id = floor(moved);
	vec2 chance = air_hash(id + seed);
	if (chance.x > share) {
		return 0.0;
	}
	vec2 own = air_hash(id * 1.7 + seed + 3.1);
	vec2 home = 0.25 + 0.5 * own;
	home += 0.07 * vec2(sin(clock * (0.5 + own.x) + own.y * 40.0), cos(clock * (0.4 + own.y) + own.x * 40.0));
	float far = length((fract(moved) - home) * cell);
	float size = across * (0.6 + 0.8 * chance.y);
	float body = smoothstep(size, size * 0.25, far);
	float halo = smoothstep(size * 3.2, 0.0, far) * 0.3;
	float lit = 1.0 - flicker * (0.5 + 0.5 * sin(clock * (2.0 + 4.0 * own.x) + own.y * 30.0));
	return (body + halo) * lit;
}

void fragment() {
	vec2 at = sheet_from + UV * sheet_size;
	float sum = motes(at, 180.0, 1.0, 0.0) + motes(at, 260.0, 0.6, 17.0) * 0.7;
	COLOR = vec4(mote.rgb, mote.a * sum);
}
