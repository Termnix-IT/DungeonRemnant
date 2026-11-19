// The chapter's route cut into the stone tablet over the hall (RouteTablet).
// Drawn on the tablet's own picture: every way between two areas is a groove
// chiselled into the slate (a short run straight out of an area, a slant,
// and a short run straight into the next, so that where ways part and meet
// is read at a glance), every area a socket ringed with bronze, and light
// stands in them the way it stands in the gates: the way walked filled with
// gold, the way to the gate turned to running with that gate's light, the
// ways still open beyond it glowing faintly; a way out of reach is only
// scratched. Along its foot a row of small stones counts the stages to the
// boss.
//
// Places are in px of the tablet (`size` across the whole picture).
shader_type canvas_item;

const int WAYS = 96;
const int AREAS = 20;
const int STAGES = 8;
// The bronze round a socket.
const float RING = 2.6;
const vec3 BRONZE = vec3(0.4, 0.31, 0.19);

uniform vec2 size = vec2(820.0, 105.0);
// How much of the slab's own paint shows (it hangs in a dark hall).
uniform float shade = 0.62;
uniform int way_count = 0;
// A stretch of a way: from (xy) to (zw); its light (rgb) and the light's
// strength (a); how far along it the light has come (x: 0 to 1), how
// strongly beads of light run along it (y), half its width (z) and how
// deep it is cut (w: 1, or less for one only scratched).
uniform vec4 way[96];
uniform vec4 way_tone[96];
uniform vec4 way_run[96];
uniform int area_count = 0;
// An area: its middle (xy), its socket's radius (z) and its shape (w: 0 a
// round, 1 the boss's lozenge, 2 the round she stands at, which wears a
// turning compass); its jewel's light (rgb) and strength (a); the ring of
// the one turned to (x) and the glow round it (y).
uniform vec4 area[20];
uniform vec4 area_tone[20];
uniform vec2 area_ring[20];
// The stages along the foot: how many, where each lies across, their line,
// and each one's light.
uniform int stage_count = 0;
uniform float stage_x[8];
uniform float stage_y = 96.0;
uniform vec4 stage_tone[8];
uniform float clock = 0.0;

void fragment() {
	vec4 slab = texture(TEXTURE, UV);
	vec2 p = UV * size;
	vec3 col = slab.rgb * shade;
	vec3 emit = vec3(0.0);

	// The grooves: each is cut as deep as it is, the deepest here showing,
	// and each adds the light that stands in it (the brightest here showing,
	// so that two stretches meeting make no knot of light).
	float cut = 0.0;
	float lip = 0.0;
	vec2 normal = vec2(0.0, 1.0);
	for (int index = 0; index < WAYS; index++) {
		if (index >= way_count) {
			break;
		}
		vec2 a = way[index].xy;
		vec2 run = way[index].zw - a;
		float len = max(length(run), 0.001);
		float along = clamp(dot(p - a, run) / (len * len), 0.0, 1.0);
		vec2 off = p - (a + run * along);
		float d = length(off);
		if (d > 26.0) {
			continue;
		}
		float half_wide = way_run[index].z;
		float deep = way_run[index].w;
		float here = (1.0 - smoothstep(half_wide - 0.6, half_wide + 0.6, d)) * deep;
		cut = max(cut, here);
		float edge = smoothstep(half_wide + 2.0, half_wide + 0.4, d) * deep;
		if (edge > lip) {
			lip = edge;
			normal = off / max(d, 0.001);
		}
		vec4 tone = way_tone[index];
		if (tone.a > 0.0) {
			float filled = way_run[index].x;
			float shown = filled >= 1.0 ? 1.0 : 1.0 - smoothstep(filled - 0.06, filled + 0.06, along);
			float head = exp(-pow((along - filled) * len / 8.0, 2.0)) * step(0.03, filled) * step(filled, 0.97);
			float core = 1.0 - smoothstep(half_wide * 0.5, half_wide + 0.5, d);
			float halo = exp(-pow(d / (4.5 + half_wide), 2.0));
			float bead = pow(max(sin((dot(p - a, run) / len / 26.0 - clock * 1.5) * 6.2831853), 0.0), 8.0) * way_run[index].y;
			emit = max(emit, tone.rgb * tone.a * ((core * 1.15 + halo * 0.32) * shown + head * (core + halo) * 1.4 + bead * shown * (core * 1.3 + exp(-pow(d / 4.0, 2.0)) * 0.9)));
		}
	}
	lip *= 1.0 - cut;
	col *= mix(1.0, 0.42, cut);
	// The chisel's edge: lit from above on its lower lip, in shade on its upper.
	col += vec3(0.16, 0.15, 0.14) * lip * max(dot(normal, vec2(0.45, 0.89)), 0.0);
	col *= 1.0 - 0.4 * lip * max(dot(normal, vec2(-0.45, -0.89)), 0.0);

	// The stages along the foot: small stones set into the bronze.
	for (int index = 0; index < STAGES; index++) {
		if (index >= stage_count) {
			break;
		}
		vec2 q = p - vec2(stage_x[index], stage_y);
		float d = abs(q.x) + abs(q.y);
		vec4 tone = stage_tone[index];
		float stone = 1.0 - smoothstep(3.0, 4.0, d);
		float seat = (1.0 - smoothstep(4.6, 5.6, d)) * (1.0 - stone);
		col = mix(col, vec3(0.05, 0.045, 0.05), seat);
		col = mix(col, vec3(0.06, 0.055, 0.06) + tone.rgb * tone.a, stone);
		emit += tone.rgb * tone.a * exp(-pow(d / 7.0, 2.0)) * 0.35 * (1.0 - stone);
	}

	// The sockets, over the grooves' ends.
	for (int index = 0; index < AREAS; index++) {
		if (index >= area_count) {
			break;
		}
		vec2 q = p - area[index].xy;
		float radius = area[index].z;
		float shape = area[index].w;
		float d = shape > 0.5 && shape < 1.5 ? (abs(q.x) + abs(q.y)) * 0.78 : length(q);
		if (d > radius + 30.0) {
			continue;
		}
		vec4 tone = area_tone[index];
		float inside = 1.0 - smoothstep(radius - 0.6, radius + 0.6, d);
		float ring = (1.0 - smoothstep(radius + RING - 0.6, radius + RING + 0.6, d)) * (1.0 - inside);
		// The bronze round it, brighter on the side the hall's light comes from.
		float turn = dot(normalize(q + vec2(0.0001)), vec2(-0.5, -0.86));
		vec3 metal = BRONZE * (0.62 + 0.5 * turn) + tone.rgb * tone.a * 0.22;
		col = mix(col, metal, ring);
		// The jewel in it: dark until light stands in it.
		float bowl = clamp(1.0 - d / max(radius, 0.001), 0.0, 1.0);
		vec3 jewel = vec3(0.035, 0.033, 0.04) + tone.rgb * tone.a * (0.5 + 0.6 * bowl);
		vec2 glint = (q - vec2(-0.3, -0.36) * radius) / (radius * 0.3);
		jewel += vec3(1.0) * exp(-dot(glint, glint)) * 0.42 * min(tone.a, 1.2);
		col = mix(col, jewel, inside);
		emit *= 1.0 - inside * 0.9;
		// Its glow on the stone round it, and the ring of the one turned to.
		float out_by = max(d - radius - RING, 0.0);
		emit += tone.rgb * area_ring[index].y * exp(-pow(out_by / 8.5, 2.0)) * (1.0 - inside) * 0.62;
		float mark = exp(-pow((d - radius - RING - 4.4 - 1.2 * sin(clock * 3.0)) / 1.15, 2.0));
		emit += tone.rgb * area_ring[index].x * mark;
		// Where she is: a compass of four points turning slowly round it.
		if (shape > 1.5) {
			float about = atan(q.y, q.x) + clock * 0.55;
			float point = pow(max(cos(about * 4.0), 0.0), 14.0);
			float reach = smoothstep(radius + RING + 1.5, radius + RING + 3.5, d) * (1.0 - smoothstep(radius + RING + 6.5, radius + RING + 10.5, d));
			emit += tone.rgb * point * reach * 1.25;
			emit += tone.rgb * exp(-pow((d - radius - RING - 2.6) / 0.9, 2.0)) * 0.55;
		}
	}
	COLOR = vec4(col + emit, slab.a * COLOR.a);
}
