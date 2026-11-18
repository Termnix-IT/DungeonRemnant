// The chapter's route cut into the stone tablet over the hall (RouteTablet).
// Drawn on the tablet's own picture: every way between two areas is a groove
// chiselled into the slate, every area a socket ringed with bronze, and
// light stands in them the way it stands in the gates: the way walked filled
// with gold, the way to the gate turned to running with that gate's light,
// the ways still open beyond it glowing faintly, the rest cut and dark.
//
// Places are in px of the tablet (`size` across the whole picture).
shader_type canvas_item;

const int WAYS = 40;
const int AREAS = 20;
// A groove's half width, and the bronze round a socket.
const float GROOVE = 1.7;
const float RING = 2.6;
const vec3 BRONZE = vec3(0.4, 0.31, 0.19);

uniform vec2 size = vec2(736.0, 94.0);
// How much of the slab's own paint shows (it hangs in a dark hall).
uniform float shade = 0.62;
uniform int way_count = 0;
// A way: from (xy) to (zw); its light (rgb) and the light's strength (a);
// how far along it the light has come (x: 0 to 1) and how strongly beads
// of light run along it (y).
uniform vec4 way[40];
uniform vec4 way_tone[40];
uniform vec2 way_run[40];
uniform int area_count = 0;
// An area: its middle (xy), its socket's radius (z) and its shape (w: 0 a
// round, 1 the boss's lozenge); its jewel's light (rgb) and strength (a);
// the ring of the one turned to (x) and the glow round it (y).
uniform vec4 area[20];
uniform vec4 area_tone[20];
uniform vec2 area_ring[20];
uniform float clock = 0.0;

void fragment() {
	vec4 slab = texture(TEXTURE, UV);
	vec2 p = UV * size;
	vec3 col = slab.rgb * shade;
	vec3 emit = vec3(0.0);

	// The grooves: the nearest is cut into the stone, and each adds the
	// light that stands in it.
	float nearest = 1000.0;
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
		if (d < nearest) {
			nearest = d;
			normal = off / max(d, 0.001);
		}
		vec4 tone = way_tone[index];
		if (tone.a > 0.0 && d < 24.0) {
			float filled = way_run[index].x;
			float shown = filled >= 1.0 ? 1.0 : 1.0 - smoothstep(filled - 0.04, filled + 0.04, along);
			float head = exp(-pow((along - filled) * len / 9.0, 2.0)) * step(0.02, filled) * step(filled, 0.98);
			float core = 1.0 - smoothstep(GROOVE * 0.4, GROOVE + 0.5, d);
			float halo = exp(-pow(d / 6.5, 2.0));
			float bead = pow(max(sin((along * len / 26.0 - clock * 1.5) * 6.2831853), 0.0), 8.0) * way_run[index].y;
			emit += tone.rgb * tone.a * ((core * 1.15 + halo * 0.3) * shown + head * (core + halo) * 1.4 + bead * shown * (core * 1.3 + exp(-pow(d / 4.0, 2.0)) * 0.9));
		}
	}
	float cut = 1.0 - smoothstep(GROOVE - 0.6, GROOVE + 0.6, nearest);
	float lip = smoothstep(GROOVE + 2.0, GROOVE + 0.4, nearest) * (1.0 - cut);
	col *= mix(1.0, 0.46, cut);
	// The chisel's edge: lit from above on its lower lip, in shade on its upper.
	col += vec3(0.16, 0.15, 0.14) * lip * max(dot(normal, vec2(0.45, 0.89)), 0.0);
	col *= 1.0 - 0.4 * lip * max(dot(normal, vec2(-0.45, -0.89)), 0.0);

	// The sockets, over the grooves' ends.
	for (int index = 0; index < AREAS; index++) {
		if (index >= area_count) {
			break;
		}
		vec2 q = p - area[index].xy;
		float radius = area[index].z;
		float d = area[index].w > 0.5 ? (abs(q.x) + abs(q.y)) * 0.78 : length(q);
		if (d > radius + 26.0) {
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
		emit *= 1.0 - inside * 0.85;
		// Its glow on the stone round it, and the ring of the one turned to.
		float out_by = max(d - radius - RING, 0.0);
		emit += tone.rgb * area_ring[index].y * exp(-pow(out_by / 7.5, 2.0)) * (1.0 - inside) * 0.6;
		float mark = exp(-pow((d - radius - RING - 4.2 - 1.2 * sin(clock * 3.0)) / 1.1, 2.0));
		emit += tone.rgb * area_ring[index].x * mark;
	}
	COLOR = vec4(col + emit, slab.a * COLOR.a);
}
